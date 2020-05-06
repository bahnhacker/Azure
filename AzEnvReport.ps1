## script captures configurations and settings for key features and services in azure
##
## variables: set via prompts during execution
##
##
## created/modified: 202005
## change log:
## 202004 - created
## 20200504 - ad records expanding to include all objects, added additional if statements to skip null results to resolve errors
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

## required PSmodules ##################################################################################################
if (Get-Module -ListAvailable -Name ImportExcel) {
    Import-Module ImportExcel
} 
else {
    Write-Host "Installing the ImportExcel Module"
    Install-Module ImportExcel -AllowClobber -Scope AllUsers
    Import-Module ImportExcel
}

if (Get-Module -ListAvailable -Name Az) {
    Import-Module Az
} 
else {
    Write-Host "Installing the Az Module"
    Install-Module Az -AllowClobber -Scope AllUsers
    Import-Module Az
}

if (Get-Module -ListAvailable -Name AzureAD) {
    Import-Module AzureAD
} 
else {
    Write-Host "Installing the AzureAD Module"
    Install-Module AzureAD -AllowClobber -Scope AllUsers
    Import-Module AzureAD
}

## variables ###########################################################################################################
## custom variables 
#$file_name = "C:\tmp" ## udpate file location

## prompts
$client = Read-Host -Prompt "Client Name?"
$dirid = Read-Host -Prompt "TenantID or AzureAD DirectoryID?"

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

## system PS variables
$date = Get-Date -f yyyyMMdd
$outputfilename = ("$client" + "-AzureReport-" + $date)
$wkbk = "$select_path\$outputfilename.xlsx"

########################################################################################################################
########### start of script ########## start of script ########## start of script ########## start of script ###########
########################################################################################################################
$creds = Get-Credential
Connect-AzAccount -Tenant $dirid -Credential $creds
Connect-AzureAD -TenantId $dirid -Credential $creds

## AZURE AD ############################################################################################################
Get-AzureADDirectoryRole | Select-Object -Property DisplayName,Description,ObjectID | Export-Excel -Path $wkbk -WorksheetName "Roles" -BoldTopRow -FreezeTopRow -AutoSize
$item = Import-Excel -Path $wkbk -WorksheetName "Roles"
foreach ($line in $item){
    $value = Get-AzureADDirectoryRoleMember -ObjectId $line.ObjectId
    if ($value -ne $null)
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
    if ($value -ne $null)
    {
        Get-AzureADGroupMember -ObjectId $line.ObjectId -All $true `
        | Select-Object @{n="Group";e={$line.DisplayName -join ","}},DisplayName,UserPrincipalName,ObjectId `
        | Export-Excel -Path $wkbk -WorksheetName "AAD-GrpMbr" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}

## FRAMEWORK ###########################################################################################################
$ten_name = (Get-AzManagementGroup).Name
Get-AzManagementGroup -GroupName $ten_name -Expand -Recurse | Select-Object -Property DisplayName,Name,Type,ID | Export-Excel -Path $wkbk -WorksheetName "MG" -BoldTopRow -FreezeTopRow -AutoSize
(Get-AzManagementGroup -GroupName $ten_name -Expand -Recurse).Children | Select-Object -Property DisplayName,Name,Type,ID | Export-Excel -Path $wkbk -WorksheetName "MG" -BoldTopRow -FreezeTopRow -AutoSize -Append
# IF the above two cmds fail, then the cliet has multiple management groups directly under the Tenant Root. Run this cmd for each MG editing for the name of each MG: 
# Get-AzManagementGroup -GroupName "Management Group Name" -Expand -Recurse | Select-Object -Property DisplayName,Name,Type,ID | Export-Excel -Path $wkbk -WorksheetName "MG" -BoldTopRow -FreezeTopRow -AutoSize -Append

$item = Import-Excel -Path $wkbk -WorksheetName "MG"
foreach ($line in $item){
    Get-AzRoleAssignment -Scope $line.Id -IncludeClassicAdministrators `
    | Select-Object @{n="Management Group";e={$line.DisplayName -join ","}},RoleDefinitionName,DisplayName,ObjectType,Scope `
    | Export-Excel -Path $wkbk -WorksheetName "MG-RBAC" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
}
Get-AzSubscription -TenantId $dirid | Select-Object -Property Name,ID,TenantId,State | Export-Excel -Path $wkbk -WorksheetName "Sub" -BoldTopRow -FreezeTopRow -AutoSize
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
    if ($value -ne $null)
    {
        Get-AzResourceGroup `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},ResourceGroupName,Location,ResourceId `
        | Export-Excel -Path $wkbk -WorksheetName "RG" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
$item = Import-Excel -Path $wkbk -WorksheetName "RG"
foreach ($line in $item){
    Get-AzRoleAssignment -Scope $line.ResourceID `
    | Select-Object @{n="Subscription";e={$line.Subscription -join ","}},@{n="ResourceGroupName";e={$line.ResourceGroupName -join ","}},RoleDefinitionName,DisplayName,ObjectType,Scope `
    | Export-Excel -Path $wkbk -WorksheetName "RG-RBAC" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
}

## NETWORKING ##########################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -SubscriptionId $line.Id
    $value = Get-AzVirtualNetwork
    if ($value -ne $null)
    {
        Get-AzVirtualNetwork `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,@{n="AddressSpace";e={$_.AddressSpace.AddressPrefixes -join ","}},EnableDdosProtection,DdosProtectionPlan,@{n="Peering Name";e={$_.VirtualNetworkPeerings.Name -join ","}},@{n="Peering State";e={$_.VirtualNetworkPeerings.PeeringState -join ","}},@{n="Peered Address";e={$_.VirtualNetworkPeerings.RemoteVirtualNetworkAddressSpace.AddressPrefixes -join ","}},Id `
        | Export-Excel -Path $wkbk -WorksheetName "VNet" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
$item = Import-Excel -Path $wkbk -WorksheetName "VNet"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Subscription
    $value = Get-AzVirtualNetworkSubnetConfig
    if ($value -ne $null)
    {
        Get-AzVirtualNetworkSubnetConfig -VirtualNetwork (Get-AzVirtualNetwork -ResourceGroupName $line.ResourceGroupName -Name $line.Name) `
        | Select-Object @{n="Subscription";e={$line.Subscription -join ","}},@{n="VNet";e={$line.Name -join ","}},Name,@{n="AddressPrefix";e={$_.AddressPrefix -join ","}},NatGateway,Id `
        | Export-Excel -Path $wkbk -WorksheetName "Subnet" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzNetworkSecurityGroup
    if ($value -ne $null)
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
    if ($value -ne $null)
    {
        Get-AzNetworkSecurityGroup -Name $line.Name -ResourceGroupName $line.ResourceGroupName `
        | Get-AzNetworkSecurityRuleConfig | Select-Object @{n="Subscription";e={$line.Subscription -join ","}},@{n="NSG";e={$line.Name -join ","}},Name,Description,Protocol,@{n="SourcePortRange";e={$_.SourcePortRange -join ","}},@{n="DestinationPortRange";e={$_.DestinationPortRange -join ","}},@{n="SourceAddressPrefix";e={$_.SourceAddressPrefix -join ","}},@{n="DestinationAddressPrefix";e={$_.DestinationAddressPrefix -join ","}},@{n="SourceApplicationSecurityGroups";e={$_.SourceApplicationSecurityGroups -join ","}},@{n="DestinationApplicationSecurityGroups";e={$_.DestinationApplicationSecurityGroups -join ","}},Access,Priority,Direction `
        | Export-Excel -Path $wkbk -WorksheetName "NSG-Rules" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzPublicIpAddress
    if ($value -ne $null)
    {
        Get-AzPublicIpAddress `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,ResourceGuid,PublicIpAllocationMethod,IpAddress,@{n="DomainNameLabel";e={$_.DnsSettings.DomainNameLabel -join ","}},@{n="IpConfiguration";e={$_.IpConfiguration.Id -join ","}},Id `
        | Export-Excel -Path $wkbk -WorksheetName "PubIP" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}

## KEY VAULT ###########################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzKeyVault
    if ($value -ne $null)
    {
        Get-AzKeyVault `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},VaultName,ResourceGroupName,Location,ResourceId `
        | Export-Excel -Path $wkbk -WorksheetName "KeyVault" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}

## AUTOMATION ACCOUNT ##################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzAutomationAccount
    if ($value -ne $null)
    {
        Get-AzAutomationAccount `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},AutomationAccountName,ResourceGroupName,Location `
        | Export-Excel -Path $wkbk -WorksheetName "Auto" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}

## LOG ANALYTICS #######################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzOperationalInsightsWorkspace
    if ($value -ne $null)
    {
        Get-AzOperationalInsightsWorkspace `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,Sku,ResourceId `
        | Export-Excel -Path $wkbk -WorksheetName "LogAnalytics" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}

## RECOVERY SERVICES VAULT #############################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzRecoveryServicesVault
    if ($value -ne $null)
    {
        Get-AzRecoveryServicesVault `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,Type,ID `
        | Export-Excel -Path $wkbk -WorksheetName "RecoveryVault" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}

## STORAGE ACCOUNT #####################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    $value = Get-AzStorageAccount
    if ($value -ne $null)
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
    if ($value -ne $null)
    {
        Get-AzVM `
        | Select-Object @{n="Subscription";e={$line.Name -join ","}},Name,ResourceGroupName,Location,@{n="VMSize";e={$_.HardwareProfile.VmSize -join ","}},@{n="OsType";e={$_.StorageProfile.OsDisk.OsType -join ","}},@{n="ImageType";e={$_.StorageProfile.ImageReference.Offer -join ","}},@{n="Image";e={$_.StorageProfile.ImageReference.Sku -join ","}},@{n="DiskName";e={$_.StorageProfile.OsDisk.Name -join ","}},@{n="Id";e={$_.Id -join ","}} `
        | Export-Excel -Path $wkbk -WorksheetName "VM" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
    }
}

## POLICY ##############################################################################################################
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    Get-AzPolicyAssignment `
    | Select-Object -Property Name,@{n="DisplayName";e={$_.Properties.displayName -join ","}},@{n="Enforcement";e={$_.Properties.enforcementMode -join ","}},@{n="Scope";e={$_.Properties.scope -join ","}},ResourceId `
    | Export-Excel -Path $wkbk -WorksheetName "Policy" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append

}
$item = Import-Excel -Path $wkbk -WorksheetName "Sub"
foreach ($line in $item)
{
    Select-AzSubscription -Subscription $line.Id
    Get-AzPolicyState `
    | Select-Object -Property PolicyDefinitionReferenceId,IsCompliant,ComplianceState,PolicyDefinitionAction,PolicyDefinitionCategory,SubscriptionId,PolicyAssignmentScope,ResourceId `
    | Export-Excel -Path $wkbk -WorksheetName "PolicyState" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append

}


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