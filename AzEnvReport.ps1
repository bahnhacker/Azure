## script captures configurations and settings for key features and services in azure
## the script is intended to be ran as a whole and will pause for data verification at key points
##
## variables: set via prompts during execution
##
## change log:
## 202011 - restructured, updated, modules added for Security Center and Advisor
## 202006 - updated information included on the tabs for AzFramework and AzNetworking, added Disks, added BackupPolicies, added conditional formatting throughout
## 20200515 - restructure of how management group data is pulled, addition of AzFramework and AzNetworking worksheets
## 20200506 - null expressions corrected, vnet variable added to resolve errors
## 20200504 - ad records expanding to include all objects, added additional if statements to skip null results to resolve errors
## 202004 - published
########################################################################################################################
########################################################################################################################
<#
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
 if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
  $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
  Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
  Exit
 }
}
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
#>
########################################################################################################################
########### start of script ########## start of script ########## start of script ########## start of script ###########
########################################################################################################################
Import-Module Az
Import-Module AzureAD
Import-Module ImportExcel
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
$client = Read-Host -Prompt "Client Name?"
$dirid = Read-Host -Prompt "TenantID or AzureAD DirectoryID?"
$creds = Get-Credential
$wshell = New-Object -ComObject Wscript.Shell
  $answer = $wshell.Popup("Is the Azure enviornment commercial cloud?",0,"Alert",0x4)
if($answer -eq 6){
    Connect-AzAccount -Tenant $dirid -Credential $creds
    Connect-AzureAD -TenantId $dirid -Credential $creds
    }
if($answer -eq 7){
    Connect-AzAccount -Tenant $dirid -Credential $creds -EnvironmentName AzureUSGovernment
    Connect-AzureAD -TenantId $dirid -Credential $creds -AzureEnvironmentName AzureUSGovernment
    }
Function Select-FolderDialog  ## prompts user to select file location
{
    param([string]$Description="Select the location to save the file",[string]$RootFolder="Desktop")

 [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
     Out-Null     

   $objForm = New-Object System.Windows.Forms.FolderBrowserDialog
        $objForm.Rootfolder = $RootFolder
        $objForm.Description = $Description
        $Show = $objForm.ShowDialog()
        If ($Show -eq "OK")
        {
            Return $objForm.SelectedPath
        }
        Else
        {
            Write-Error "Operation cancelled by user."
        }
    }
$select_path = Select-FolderDialog
$date = Get-Date -f yyyyMMdd
$outputfilename = ("$client" + "-AzEnvReport-" + $date)
$wkbk = "$select_path\$outputfilename.xlsx"
$wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("The script will pause at set points and launch the output file for verification. After confirming valid output, close the workbook then return to the PS prompt to Continue.",0,"Alert",0x0)
$ButtonType = [System.Windows.MessageBoxButton]::YesNo
$MessageboxTitle = "scan paused..."
$Messageboxbody = "Please verify data within the report. Do you want to continue?"
$MessageIcon = [System.Windows.MessageBoxImage]::Warning
#### AZURE AD ######################## AZURE AD ######################## AZURE AD ######################## AZURE AD ####
Get-AzureADDirectoryRole | Select-Object -Property DisplayName,Description,ObjectID | Export-Excel -Path $wkbk -WorksheetName "Roles" -BoldTopRow -FreezeTopRow -AutoSize
$item = Import-Excel -Path $wkbk -WorksheetName "Roles"
foreach ($line in $item){
    $value = Get-AzureADDirectoryRoleMember -ObjectId $line.ObjectId
    if ($null -ne $value)
    {
        Get-AzureADDirectoryRoleMember -ObjectId $line.ObjectId `
        | Select-Object @{n="AzureAD Role";e={$line.DisplayName -join ","}},DisplayName,UserPrincipalName,ObjectId `
        | Export-Excel -Path $wkbk -WorksheetName "AAD-RBAC" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
Get-AzureADUser -All $true | Select-Object -Property DisplayName,MailNickName,UserPrincipalName,DirSyncEnabled,UserType,ObjectId | Export-Excel -Path $wkbk -WorksheetName "AAD-Usr" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize
Get-AzureADGroup -All $true | Select-Object -Property DisplayName,Description,MailEnabled,MailNickname,DirSyncEnabled,ObjectId | Export-Excel -Path $wkbk -WorksheetName "AAD-Grp" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize
$item = Import-Excel -Path $wkbk -WorksheetName "AAD-Grp"
foreach ($line in $item){
    $value = Get-AzureADGroup -ObjectId $line.ObjectId | Where-Object {$_.DirSyncEnabled -eq $null} 
    if ($null -ne $value)
    {
        Get-AzureADGroupMember -ObjectId $line.ObjectId -All $true `
        | Select-Object @{n="Group";e={$line.DisplayName -join ","}},DisplayName,UserPrincipalName,ObjectId `
        | Export-Excel -Path $wkbk -WorksheetName "AAD-GrpMbr" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
Invoke-Item $wkbk
[System.Windows.MessageBox]::Show($Messageboxbody,$MessageboxTitle,$ButtonType,$messageicon)
#### MANAGEMENT HIERARCHY ######## MANAGEMENT HIERARCHY ######## MANAGEMENT HIERARCHY ######## MANAGEMENT HIERARCHY ####
## MANAGEMENT GROUP ####################################################################################################
$wshell = New-Object -ComObject Wscript.Shell
  $answer = $wshell.Popup("Does the client use Azure Management Groups?",0,"Alert",0x4)
if($answer -eq 6){
    $ten_name = (Get-AzManagementGroup).Name
    Get-AzManagementGroup -GroupName $ten_name -Expand -Recurse `
        | Select-Object -Property DisplayName,Name,Type,ID,@{n="ParentID";e={""}} `
        | Export-Excel -Path $wkbk -WorksheetName "MG" -BoldTopRow -FreezeTopRow -AutoSize
    (Get-AzManagementGroup -GroupName $ten_name -Expand -Recurse).Children `
        | Select-Object -Property DisplayName,Name,Type,ID,@{n="ParentID";e={(Get-AzManagementGroup).Id -join ","}} `
        | Export-Excel -Path $wkbk -WorksheetName "MG" -BoldTopRow -FreezeTopRow -AutoSize -Append
    (Get-AzManagementGroup -GroupName $ten_name -Expand -Recurse).Children.Children `
        | Select-Object -Property DisplayName,Name,Type,ID,@{n="ParentID";e={((Get-AzManagementGroup).Children).Id -join ","}} `
        | Export-Excel -Path $wkbk -WorksheetName "MG" -BoldTopRow -FreezeTopRow -AutoSize -Append
    $item = Import-Excel -Path $wkbk -WorksheetName "MG"
    foreach ($line in $item){
        if ($line.Type -ne "/subscriptions"){
            Get-AzManagementGroup -GroupName $line.Name -Expand -Recurse `
            | Select-Object @{n="ResourceType";e={"MG" -join ","}},@{n="ResourceName";e={$_.DisplayName -join ","}},@{n="ParentName";e={$_.ParentDisplayName -join ","}},@{n="AzRegion";e={""}},@{n="Info";e={""}},@{n="Id";e={$_.Id}},@{n="ParentID";e={$line.ParentID -join ","}} `
            | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
        }
    }
    $item = Import-Excel -Path $wkbk -WorksheetName "MG"
    foreach ($line in $item){
        if ($line.Type -ne "/subscriptions"){
            Get-AzRoleAssignment -Scope $line.Id -IncludeClassicAdministrators `
            | Select-Object @{n="Management Group";e={$line.DisplayName -join ","}},RoleDefinitionName,DisplayName,ObjectType,Scope `
            | Export-Excel -Path $wkbk -WorksheetName "MG-RBAC" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
        }
    }
} 
## SUBSCRIPTION ########################################################################################################
Get-AzSubscription -TenantId $dirid `
    | Select-Object -Property Name,ID,TenantId,State `
    | Export-Excel -Path $wkbk -WorksheetName "Sub" -BoldTopRow -FreezeTopRow -AutoSize
if($answer -eq 6){
    $parent = "UPDATE REQUIRED"
    $parentID = "UPDATE REQUIRED"
} else {
    $parent = "Tenant Root Group"
    $parentID = "Tenant Root Group"
}
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item){
    Get-AzSubscription -TenantId $dirid -SubscriptionId $line.Id `
        | Select-Object @{n="ResourceType";e={"Sub" -join ","}},@{n="ResourceName";e={$_.Name -join ","}},@{n="ParentName";e={"$parent" -join ","}},@{n="AzRegion";e={""}},@{n="Info";e={$_.State}},@{n="Id";e={$line.Id}},@{n="ParentID";e={"$parentID"}} `
        | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
    Get-AzSubscription -TenantId $dirid -SubscriptionId $line.Id `
        | Select-Object @{n="ResourceType";e={"Sub" -join ","}},@{n="ResourceName";e={$_.Name -join ","}},@{n="ParentName";e={"" -join ","}},@{n="AzRegion";e={""}},@{n="Info";e={$_.State}},@{n="Id";e={$line.Id}},@{n="ParentID";e={""}} `
        | Export-Excel -Path $wkbk -WorksheetName "AzNetworking" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
}
Export-Excel -Path $wkbk -WorksheetName "AzFramework" -ConditionalText $(
    New-ConditionalText -ConditionalType Equal -Text "UPDATE REQUIRED" cyan
)
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item){
    $id = $line.Id
    Get-AzRoleAssignment -Scope /subscriptions/$id `
    | Select-Object @{n="Subscription";e={$line.Name -join ","}},RoleDefinitionName,DisplayName,ObjectType,Scope `
    | Export-Excel -Path $wkbk -WorksheetName "Sub-RBAC" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
}
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzResourceGroup
    if ($null -ne $value)
    {
        Get-AzResourceGroup `
            | Select-Object @{n="Subscription";e={$line.Name -join ","}},ResourceGroupName,Location,ResourceId `
            | Export-Excel -Path $wkbk -WorksheetName "RG" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
        Get-AzResourceGroup `
            | Select-Object @{n="ResourceType";e={"RG" -join ","}},@{n="ResourceName";e={$_.ResourceGroupName -join ","}},@{n="ParentName";e={$line.Name -join ","}},@{n="AzRegion";e={$_.Location -join ","}},@{n="Info";e={""}},@{n="Id";e={$_.ResourceId}},@{n="ParentID";e={$line.Id -join ","}} `
            | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
    }
}
## RESOURCE GROUPS #####################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "RG"
foreach ($line in $item){
    Get-AzRoleAssignment -Scope $line.ResourceID `
    | Select-Object @{n="Subscription";e={$line.Subscription -join ","}},@{n="ResourceGroupName";e={$line.ResourceGroupName -join ","}},RoleDefinitionName,DisplayName,ObjectType,Scope `
    | Export-Excel -Path $wkbk -WorksheetName "RG-RBAC" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
}
Invoke-Item $wkbk
[System.Windows.MessageBox]::Show($Messageboxbody,$MessageboxTitle,$ButtonType,$messageicon)
#### NETWORKING ##################### NETWORKING ###################### NETWORKING ##################### NETWORKING ####
## VIRTUAL NETWORK #####################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -SubscriptionId $line.Id
    $value = Get-AzVirtualNetwork
    if ($null -ne $value)
    {
        Get-AzVirtualNetwork `
            | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,@{n="AddressSpace";e={$_.AddressSpace.AddressPrefixes -join ","}},@{n="DNS";e={$_.DhcpOptions.DnsServers -join ","}},EnableDdosProtection,DdosProtectionPlan,@{n="Peering Name";e={$_.VirtualNetworkPeerings.Name -join ","}},@{n="Peering State";e={$_.VirtualNetworkPeerings.PeeringState -join ","}},@{n="Peered Address";e={$_.VirtualNetworkPeerings.RemoteVirtualNetworkAddressSpace.AddressPrefixes -join ","}},Id `
            | Export-Excel -Path $wkbk -WorksheetName "VNet" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
        Get-AzVirtualNetwork `
            | Select-Object @{n="ResourceType";e={"VNet" -join ","}},@{n="ResourceName";e={$_.Name -join ","}},@{n="ParentName";e={$_.ResourceGroupName -join ","}},@{n="AzRegion";e={$_.Location -join ","}},@{n="Info";e={$_.AddressSpace.AddressPrefixes}},@{n="Id";e={$_.Id}},@{n="ParentID";e={(Get-AzResourceGroup -Name $_.ResourceGroupName).ResourceId -join ","}} `
            | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
        Get-AzVirtualNetwork `
            | Select-Object @{n="ResourceType";e={"VNet" -join ","}},@{n="ResourceName";e={$_.Name -join ","}},@{n="ParentName";e={$line.Name -join ","}},@{n="AzRegion";e={$_.Location -join ","}},@{n="Info";e={$_.AddressSpace.AddressPrefixes}},@{n="Id";e={$_.Id}},@{n="ParentID";e={$line.Id -join ","}} `
            | Export-Excel -Path $wkbk -WorksheetName "AzNetworking" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
    }
}
## SUBNET ##############################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "VNet"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Subscription
    $vnet = (Get-AzVirtualNetwork -ResourceGroupName $line.ResourceGroupName -Name $line.Name)
    $value = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet
    if ($null -ne $value)
    {
        Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet `
            | Select-Object @{n="Subscription";e={$line.Subscription -join ","}},@{n="VNet";e={$line.Name -join ","}},Name,@{n="AddressPrefix";e={$_.AddressPrefix -join ","}},NatGateway,Id `
            | Export-Excel -Path $wkbk -WorksheetName "Subnet" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
        Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet `
            | Select-Object @{n="ResourceType";e={"Subnet" -join ","}},@{n="ResourceName";e={$_.Name -join ","}},@{n="ParentName";e={$line.Name -join ","}},@{n="AzRegion";e={""}},@{n="Info";e={$_.AddressPrefix -join ","}},@{n="Id";e={$_.Id}},@{n="ParentID";e={$line.Id -join ","}} `
            | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
        Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet `
            | Select-Object @{n="ResourceType";e={"Subnet" -join ","}},@{n="ResourceName";e={$_.Name -join ","}},@{n="ParentName";e={$line.Name -join ","}},@{n="AzRegion";e={""}},@{n="Info";e={$_.AddressPrefix -join ","}},@{n="Id";e={$_.Id}},@{n="ParentID";e={$line.Id -join ","}} `
            | Export-Excel -Path $wkbk -WorksheetName "AzNetworking" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
    }
}
## NETWORK SECURITY GROUPS #############################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzNetworkSecurityGroup
    if ($null -ne $value)
    {
        Get-AzNetworkSecurityGroup `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,ResourceGuid,Id `
        | Export-Excel -Path $wkbk -WorksheetName "NSG" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
$item = Import-Excel -Path $wkbk -WorksheetName "NSG"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Subscription
    $value = Get-AzNetworkSecurityGroup -Name $line.Name -ResourceGroupName $line.ResourceGroupName | Get-AzNetworkSecurityRuleConfig
    if ($null -ne $value)
    {
        Get-AzNetworkSecurityGroup -Name $line.Name -ResourceGroupName $line.ResourceGroupName `
        | Get-AzNetworkSecurityRuleConfig | Select-Object @{n="Subscription";e={$line.Subscription -join ","}},@{n="NSG";e={$line.Name -join ","}},Name,Description,Protocol,@{n="SourcePortRange";e={$_.SourcePortRange -join ","}},@{n="DestinationPortRange";e={$_.DestinationPortRange -join ","}},@{n="SourceAddressPrefix";e={$_.SourceAddressPrefix -join ","}},@{n="DestinationAddressPrefix";e={$_.DestinationAddressPrefix -join ","}},@{n="SourceApplicationSecurityGroups";e={$_.SourceApplicationSecurityGroups -join ","}},@{n="DestinationApplicationSecurityGroups";e={$_.DestinationApplicationSecurityGroups -join ","}},Access,Priority,Direction `
        | Export-Excel -Path $wkbk -WorksheetName "NSG-Rules" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
Export-Excel -Path $wkbk -WorksheetName "NSG-Rules" -ConditionalText $(
    New-ConditionalText -Range G:G -ConditionalType Equal -Text * red
    New-ConditionalText -Range G:G -ConditionalType Equal -Text 22 red
    New-ConditionalText -Range G:G -ConditionalType Equal -Text 3389 red
    New-ConditionalText -Range G:G -ConditionalType Equal -Text 5985 red
    New-ConditionalText -Range G:G -ConditionalType Equal -Text 5986 red
)
## PUBLIC IP ###########################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzPublicIpAddress
    if ($null -ne $value)
    {
        Get-AzPublicIpAddress `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,ResourceGuid,PublicIpAllocationMethod,IpAddress,@{n="DomainNameLabel";e={$_.DnsSettings.DomainNameLabel -join ","}},@{n="IpConfiguration";e={$_.IpConfiguration.Id -join ","}},Id `
        | Export-Excel -Path $wkbk -WorksheetName "PubIP" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
Export-Excel -Path $wkbk -WorksheetName "PubIP" -ConditionalText $(
    New-ConditionalText -Range G:G -ConditionalType Equal -Text "Not Assigned" green
)
Invoke-Item $wkbk
[System.Windows.MessageBox]::Show($Messageboxbody,$MessageboxTitle,$ButtonType,$messageicon)
#### COMPUTE & STORAGE ############ COMPUTE & STORAGE ############ COMPUTE & STORAGE ############ COMPUTE & STORAGE ####
## RECOVERY SERVICES VAULT #############################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzRecoveryServicesVault
    if ($null -ne $value)
    {
        Get-AzRecoveryServicesVault `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,Type,ID `
        | Export-Excel -Path $wkbk -WorksheetName "RecoveryVault" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
        Get-AzRecoveryServicesVault `
        | Select-Object @{n="ResourceType";e={"Vault" -join ","}},@{n="ResourceName";e={$_.Name -join ","}},@{n="ParentName";e={$_.ResourceGroupName -join ","}},@{n="AzRegion";e={$_.Location -join ","}},@{n="Info";e={$_.Type -join ","}},@{n="Id";e={$_.ID}},@{n="ParentID";e={$line.Id -join ","}} `
        | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
    }
}
$item = Import-Excel -Path $wkbk -WorksheetName "RecoveryVault"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Subscription
    Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $line.Id `
    | Select-Object @{n="Subscription";e={$line.Subscription -join ","}},@{n="VaultName";e={$line.Name -join ","}},Name,WorkloadType,SnapshotRetentionInDays,@{n="DailySchedule";e={$_.RetentionPolicy.IsDailyScheduleEnabled}},@{n="DailyRetention";e={$_.RetentionPolicy.DailySchedule.DurationCountInDays}},@{n="WeeklySchedule";e={$_.RetentionPolicy.IsWeeklyScheduleEnabled}},@{n="WeeklyRetention";e={$_.RetentionPolicy.WeeklySchedule.DurationCountInWeeks}},@{n="MonthlySchedule";e={$_.RetentionPolicy.IsMonthlyScheduleEnabled}},@{n="MonthlyRetention";e={$_.RetentionPolicy.MonthlySchedule.DurationCountInMonths}},@{n="YearlySchedule";e={$_.RetentionPolicy.IsYearlyScheduleEnabled}},@{n="YearlyRetention";e={$_.RetentionPolicy.YearlySchedule.DurationCountInYears}},Id,@{n="ParentID";e={$line.Id -join ","}} `
    | Export-Excel -Path $wkbk -WorksheetName "RV-BackupPolicies" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
}
Export-Excel -Path $wkbk -WorksheetName "RV-BackupPolicies" -ConditionalText $(
    New-ConditionalText -Range E2:E999 -ConditionalType GreaterThan -Text "7" red
    New-ConditionalText -Range G2:G999 -ConditionalType GreaterThan -Text "7" red
    New-ConditionalText -Range I2:I999 -ConditionalType GreaterThan -Text "4" red
    New-ConditionalText -Range K2:K999 -ConditionalType GreaterThan -Text "12" red
    New-ConditionalText -Range M2:M999 -ConditionalType GreaterThan -Text "1" red
)
## STORAGE ACCOUNT #####################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzStorageAccount
    if ($null -ne $value)
    {
        Get-AzStorageAccount `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},StorageAccountName,ResourceGroupName,PrimaryLocation,Kind,AccessTier,EnableHttpsTrafficOnly `
        | Export-Excel -Path $wkbk -WorksheetName "StorageAccount" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
## VIRTUAL MACHINE #####################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzVM
    if ($null -ne $value)
    {
        Get-AzVM `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,@{n="VMSize";e={$_.HardwareProfile.VmSize -join ","}},@{n="OsType";e={$_.StorageProfile.OsDisk.OsType -join ","}},@{n="ImageType";e={$_.StorageProfile.ImageReference.Offer -join ","}},@{n="Image";e={$_.StorageProfile.ImageReference.Sku -join ","}},@{n="DiskName";e={$_.StorageProfile.OsDisk.Name -join ","}},@{n="Id";e={$_.Id -join ","}} `
        | Export-Excel -Path $wkbk -WorksheetName "VM" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
## DISKS ###############################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    Get-AzDisk `
    | Select-Object -Property @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,DiskSizeGB,DiskState,DiskIOPSReadWrite,DiskMBpsReadWrite,Encryption,Location,Sku,ManagedBy,UniqueID,Id `
    | Export-Excel -Path $wkbk -WorksheetName "Disks" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
}
Export-Excel -Path $wkbk -WorksheetName "Disks" -ConditionalText $(
    New-ConditionalText -Range E2:E999 -ConditionalType Equal -Text "Unattached" green
)
Invoke-Item $wkbk
[System.Windows.MessageBox]::Show($Messageboxbody,$MessageboxTitle,$ButtonType,$messageicon)
#### GOVERNANCE ###################### GOVERNANCE #################### GOVERNANCE ###################### GOVERNANCE ####
## LOG ANALYTICS #######################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzOperationalInsightsWorkspace
    if ($null -ne $value)
    {
        Get-AzOperationalInsightsWorkspace `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,Sku,@{n="RetentionInDays";e={(Get-AzOperationalInsightsWorkspace -Name $_.Name -ResourceGroupName $_.ResourceGroupName).retentionInDays -join ","}},ResourceId `
        | Export-Excel -Path $wkbk -WorksheetName "LogAnalytics" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
        Get-AzOperationalInsightsWorkspace `
        | Select-Object @{n="ResourceType";e={"LA" -join ","}},@{n="ResourceName";e={$_.Name -join ","}},@{n="ParentName";e={$_.ResourceGroupName -join ","}},@{n="AzRegion";e={$_.Location -join ","}},@{n="Info";e={$_.Sku -join ","}},@{n="Id";e={$_.ResourceId}},@{n="ParentID";e={$line.Id -join ","}} `
        | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
    }
}
Export-Excel -Path $wkbk -WorksheetName "LogAnalytics" -ConditionalText $(
    New-ConditionalText -Range F2:F999 -ConditionalType GreaterThanOrEqual -Text "90" green
)
## AUTOMATION ACCOUNT ##################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzAutomationAccount
    if ($null -ne $value)
    {
        Get-AzAutomationAccount `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},AutomationAccountName,ResourceGroupName,Location `
        | Export-Excel -Path $wkbk -WorksheetName "Auto" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
        Get-AzAutomationAccount `
        | Select-Object @{n="ResourceType";e={"Auto" -join ","}},@{n="ResourceName";e={$_.AutomationAccountName -join ","}},@{n="ParentName";e={$_.ResourceGroupName -join ","}},@{n="AzRegion";e={$_.Location -join ","}},@{n="Info";e={""}},@{n="Id";e={("/subscriptions/" + $line.id + "/resourceGroups/" + $_.ResourceGroupName + "/providers/Microsoft.Automation/" + $_.AutomationAccountName) -join ","}},@{n="ParentID";e={$line.Id -join ","}} `
        | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
    }
}
## KEY VAULT ###########################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzKeyVault
    if ($null -ne $value)
    {
        Get-AzKeyVault `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},VaultName,ResourceGroupName,Location,@{n="Sku";e={(Get-AzKeyVault -VaultName $_.VaultName -ResourceGroupName $_.ResourceGroupName).Sku -join ","}},ResourceId `
        | Export-Excel -Path $wkbk -WorksheetName "KeyVault" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
        Get-AzKeyVault `
        | Select-Object @{n="ResourceType";e={"KV" -join ","}},@{n="ResourceName";e={$_.VaultName -join ","}},@{n="ParentName";e={$_.ResourceGroupName -join ","}},@{n="AzRegion";e={$_.Location -join ","}},@{n="Info";e={""}},@{n="Id";e={$_.ResourceId}},@{n="ParentID";e={$line.Id -join ","}} `
        | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
    }
}
Export-Excel -Path $wkbk -WorksheetName "KeyVault" -ConditionalText $(
    New-ConditionalText -Range E:E -ConditionalType Equal -Text "Premium" green
)
## POLICY ##############################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    Get-AzPolicyAssignment `
    | Select-Object -Property @{n="PolicyID";e={$_.Name -join ","}},@{n="DisplayName";e={$_.Properties.displayName -join ","}},@{n="Enforcement";e={$_.Properties.enforcementMode -join ","}},@{n="Scope";e={$_.Properties.scope -join ","}},ResourceId `
    | Export-Excel -Path $wkbk -WorksheetName "Policy" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
}
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    Get-AzPolicyState `
    | Select-Object -Property @{n="PolicyID";e={$_.PolicyAssignmentName -join ","}},PolicyDefinitionId,IsCompliant,ComplianceState,PolicyDefinitionAction,PolicyDefinitionCategory,SubscriptionId,PolicyAssignmentScope,ResourceId `
    | Export-Excel -Path $wkbk -WorksheetName "PolicyState" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
}
## SECURITY CENTER #####################################################################################################
Import-Module Az.Security
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzSecurityContact
    if ($null -ne $value)
    {
        Get-AzSecurityContact `
        | Select-Object -Property @{n="Subscription";e={$line.Name -join ","}},@{n="ContactName";e={$_.Name -join ","}},Email,Phone `
        | Export-Excel -Path $wkbk -WorksheetName "ASC-Contact" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
    $value = Get-AzSecurityAutoProvisioningSetting
    if ($null -ne $value)
    {
        Get-AzSecurityAutoProvisioningSetting `
        | Select-Object -Property @{n="Subscription";e={$line.Name -join ","}},@{n="AutoProvisioningName";e={$_.Name -join ","}},Id `
        | Export-Excel -Path $wkbk -WorksheetName "ASC-AutoProv" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
    $value = Get-AzSecurityWorkspaceSetting
    if ($null -ne $value)
    {
        Get-AzSecurityWorkspaceSetting `
        | Select-Object -Property @{n="Subscription";e={$line.Name -join ","}},@{n="WorkspaceName";e={$_.Name -join ","}},Scope,WorkspaceId `
        | Export-Excel -Path $wkbk -WorksheetName "ASC-Workspace" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
    $value = Get-AzSecurityPricing
    if ($null -ne $value)
    {
        Get-AzSecurityPricing `
        | Select-Object -Property @{n="Subscription";e={$line.Name -join ","}},Name,PricingTier `
        | Export-Excel -Path $wkbk -WorksheetName "ASC-Pricing" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
    $SecurityTasks = Get-AzSecurityTask
    if ($null -ne $SecurityTasks)
    {
        Get-AzSecurityTask `
        | Select-Object -Property @{n="SubscriptionID";e={$line.Id -join ","}},@{n="Subscription";e={$line.Name -join ","}},RecommendationType,ResourceId `
        | Export-Excel -Path $wkbk -WorksheetName "ASC-Tasks" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
## ADVISOR #############################################################################################################
Import-Module Az.Advisor
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    $Advisor = Get-AzAdvisorRecommendation
    if ($null -ne $Advisor)
    {
        Get-AzAdvisorRecommendation `
        | Select-Object -Property @{n="SubscriptionID";e={$line.Id -join ","}},@{n="Subscription";e={$line.Name -join ","}},Category,Impact,ImpactedValue,ResourceId `
        | Export-Excel -Path $wkbk -WorksheetName "Advisor" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("There are Azure Advisor Recommendations available. You will need to use the Portal to download the complete report.",0,"Azure Advisor",0x0)
    Export-Excel -Path $wkbk -WorksheetName "Advisor" -ConditionalText $(
        New-ConditionalText -Range D:D -ConditionalType Equal -Text High red
    )
}
########################################################################################################################
$wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("The Azure Envioronment Report script has completed.",0,"***COMPLETE***",0x0)
Invoke-Item $wkbk
########################################################################################################################
###### End of script ######## End of script ######## End of script ######## End of script ######## End of script #######
########################################################################################################################
########################################### Disclaimer for custom scripts ##############################################
###### The sample scripts are not supported under any ANY standard support program or service. The sample scripts ######
###### are provided AS IS without warranty of any kind. The author further disclaims all implied warranties       ######
###### including, without limitation, any implied warranties of merchantability or of fitness for a particular    ######
###### purpose. The entire risk arising out of the use or performance of the sample scripts and documentation     ######
###### remains with you. In no event shall the author, its authors, or anyone else involved in the creation,      ######
###### production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation,######
###### damages for loss of business profits, business interruption, loss of business information, or other        ######
###### pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if ######
###### the author has been advised of the possibility of such damages.                                            ######
########################################### Disclaimer for custom scripts ##############################################
#####################################################################################################################bps