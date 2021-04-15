## script captures configurations and settings for key features and services in azure
## the script is intended to be ran as a whole and will pause for data verification at key points
##
## execution example with switches: .\AzEnviReport_v2.ps1 -path [folder path] -interactiveauth -skipvalidation 
## .\AzPowershell\AzEnvReport_v2.ps1 -InteractiveAuth -SkipValidation
## switches; if not defined the script will prompt for the path
##    -path; allows the folder path to be defined
##    -interactiveauth; uses the web based auth, ideal for MFA
##    -skipvalidation; does not pause during the execution for export file validation
##
## change log:
## 20200125 - v2 published
## 20210125 - Updated Code to Enhance Performance (Reduced Number of Repeditive commands being called), Eliminated duplicate RBAC work
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
param(
    $Path = $null,
    [switch]$InteractiveAuth,
    [switch]$SkipValidation
)
#Import-Module Az # Commented Out Due To Az version mismatch for users who download Specific Az.* modules
Import-Module Az.Accounts
Import-Module Az.Advisor
Import-Module Az.Automation
Import-Module Az.Compute
Import-Module Az.KeyVault
Import-Module Az.Network
Import-Module Az.OperationalInsights
Import-Module Az.PolicyInsights
Import-Module Az.RecoveryServices
Import-Module Az.Resources
Import-Module Az.Security
Import-Module Az.Storage
Import-Module AzureAD
Import-Module ImportExcel
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Variables
$client = ""
$dirid = ""

# Authentication
if ( !$InteractiveAuth ) {
    # Basic Auth
    Disconnect-AzAccount
    $client = Read-Host -Prompt "Client Name?"  
    $dirid = Read-Host -Prompt "TenantID or AzureAD DirectoryID?" 
    $creds = Get-Credential
    $wshell = New-Object -ComObject Wscript.Shell
    $answer = $wshell.Popup("Is the Azure enviornment commercial cloud?", 0, "Alert", 0x4)
    if ($answer -eq 6) {
        Connect-AzAccount -Tenant $dirid -Credential $creds
        Connect-AzureAD -TenantId $dirid -Credential $creds
    }
    if ($answer -eq 7) {
        Connect-AzAccount -Tenant $dirid -EnvironmentName AzureUSGovernment -Credential $creds
        Connect-AzureAD -TenantId $dirid -AzureEnvironmentName AzureUSGovernment -Credential $creds
    }
}
else {
    # Interactive Login
    # Azure
    Disconnect-AzAccount
    $azContext = Get-AzContext
    while ( $null -eq $azContext ) { 
        $dirid = Read-Host -Prompt "TenantID or AzureAD DirectoryID?"
        Write-Host "Connecting to Azure..."
        Connect-AzAccount -Tenant $dirid
        $azContext = Get-AzContext
        #Write-Error "Azure Context Not Set. Please Login with Connect-AzAccount -Tenant <TenantID> [-EnvironmentName AzureUSGovernment]"
        #return
    }
    $dirid = $azContext.Tenant.Id

    # Azure AD
    $azAdSession = Get-AzureADCurrentSessionInfo -ErrorAction SilentlyContinue
    while ( $null -eq $azAdSession ) {
        Write-Host "Connecting to Azure AD..."
        Connect-AzureAD -TenantId $dirid
        $azAdSession = Get-AzureADCurrentSessionInfo -ErrorAction SilentlyContinue
        #Write-Error "AzureAD Session Not Set. Please Login with Connect-AzAccount -TenantId <TenantID> [-AzureEnvironmentName AzureUSGovernment]"
        #return
    }
    $client = $azAdSession.TenantDomain
}

# Data Path Code
Function Select-FolderDialog {
    ## prompts user to select file location
    param([string]$Description = "Select the location to save the file", [string]$RootFolder = "Desktop")

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
    Out-Null     

    $objForm = New-Object System.Windows.Forms.FolderBrowserDialog
    $objForm.Rootfolder = $RootFolder
    $objForm.Description = $Description
    $Show = $objForm.ShowDialog()
    If ($Show -eq "OK") {
        Return $objForm.SelectedPath
    }
    Else {
        Throw "Operation cancelled by user."
    }
}
Add-Type -AssemblyName PresentationFramework -ErrorAction Stop 
$select_path = $Path
if ( $null -eq $select_path ) {
    $select_path = Select-FolderDialog -ErrorAction Stop
}
$date = Get-Date -f yyyyMMddHHmm
$outputfilename = ("$client" + "-AzEnvReport-" + $date)
$wkbk = "$select_path\$outputfilename.xlsx"

# Data Validation Settings
$ButtonType = [System.Windows.MessageBoxButton]::YesNo
$MessageboxTitle = "scan paused..."
$Messageboxbody = "Please verify data within the report. Do you want to continue?"
$MessageIcon = [System.Windows.MessageBoxImage]::Warning

# Data Validating Notice
if ( !$SkipValidation ) {
    $wshell = New-Object -ComObject Wscript.Shell
    $wshell.Popup("The script will pause at set points and launch the output file for verification. After confirming valid output, close the workbook then return to the PS prompt to Continue.", 0, "Alert", 0x0)
}
#### AZURE AD ######################## AZURE AD ######################## AZURE AD ######################## AZURE AD ####
# Admin Roles
$roles = Get-AzureADDirectoryRole | Select-Object -Property DisplayName, Description, ObjectID
$roles | Export-Excel -Path $wkbk -WorksheetName "Roles" -BoldTopRow -FreezeTopRow -AutoSize
# Admin Role Assignments
$roleAssign = @()
foreach ($line in $roles) {
    $value = Get-AzureADDirectoryRoleMember -ObjectId $line.ObjectId
    $roleAssign += $value | Select-Object @{n = "AzureAD Role"; e = { $line.DisplayName } }, DisplayName, UserPrincipalName, ObjectId
}
$roleAssign | Export-Excel -Path $wkbk -WorksheetName "AAD-RBAC" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize
# Users
$users = Get-AzureADUser -All $true | Select-Object -Property DisplayName, MailNickName, UserPrincipalName, DirSyncEnabled, UserType, ObjectId
$users | Export-Excel -Path $wkbk -WorksheetName "AAD-Usr" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize
# Groups
$groups = Get-AzureADGroup -All $true | Select-Object -Property DisplayName, Description, MailEnabled, MailNickname, DirSyncEnabled, ObjectId
$groups | Export-Excel -Path $wkbk -WorksheetName "AAD-Grp" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize
# Group Membership
$grpMbrs = @()
$groupsNotDirSync = $groups | Where-Object { $_.DirSyncEnabled -eq $null }
foreach ($line in $groupsNotDirSync) {
    $value = Get-AzureADGroupMember -ObjectId $line.ObjectId -All $true 
    $grpMbrs += $value | Select-Object @{n = "Group"; e = { $line.DisplayName -join "," } }, DisplayName, UserPrincipalName, ObjectId
}
$grpMbrs | Export-Excel -Path $wkbk -WorksheetName "AAD-GrpMbr" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize 
# Validate Data
if ( !$SkipValidation ) {
    Invoke-Item $wkbk
    $result = [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $messageicon)
    if ( $result -eq 0 ) { return }
}
#### MANAGEMENT HIERARCHY ######## MANAGEMENT HIERARCHY ######## MANAGEMENT HIERARCHY ######## MANAGEMENT HIERARCHY ####
## MANAGEMENT GROUP ####################################################################################################
function Get-ManagementGroupData {
    param( [string]$GroupId ) 
    # Stage Return Value
    $ReturnValue = @()
    # Parent Data
    $parentMg = Get-AzManagementGroup -GroupId $GroupId -Expand -ErrorAction Stop
    $ReturnValue += $parentMg | Select-Object -Property DisplayName, Name, Type, ID, ParentId, ParentName, ParentDisplayName
    # Child Data
    $childMgs = @()
    foreach ( $child in $parentMg.Children ) {
        if ( $child.Type -eq "/subscriptions" ) {
            $ReturnValue += $child | Select-Object -Property DisplayName, Name, Type, ID, @{n = "ParentId"; e = { $parentMg.Id } }, @{n = "ParentName"; e = { $parentMg.Name } }, @{n = "ParentDisplayName"; e = { $parentMg.DisplayName } }
        }
        else {
            $childMgs += $child
        }
    }
    # Recursive For Child MGs
    foreach ( $child in $childMgs ) {
        $ReturnValue += Get-ManagementGroupData -GroupId $child.Name
    }
    # Return Data
    return $ReturnValue
}
# Excel MGs
try {
    $mgReport = Get-ManagementGroupData -GroupId $dirid
    $mgReport | Export-Excel -Path $wkbk -WorksheetName "MG" -BoldTopRow -FreezeTopRow -AutoSize
    # Excel AzFramework
    $mgAzFramework = $mgReport | Where-Object { $_.Type -ne "/subscriptions" }
    $mgAzFramework = $mgAzFramework | Select-Object @{n = "ResourceType"; e = { "MG" } }, @{n = "ResourceName"; e = { $_.DisplayName } }, @{n = "ParentName"; e = { $_.ParentDisplayName } }, @{n = "AzRegion"; e = { "" } }, @{n = "Info"; e = { "" } }, Id, ParentId
    $mgAzFramework | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart
    # Excel MG RBAC
    $mgRbac = @()
    foreach ( $line in $mgAzFramework ) {
        $mgRbac += Get-AzRoleAssignment -Scope $line.Id -IncludeClassicAdministrators | Select-Object @{n = "Management Group"; e = { $line.ResourceName -join "," } }, RoleDefinitionName, DisplayName, ObjectType, Scope
    }
    $mgRbac | Export-Excel -Path $wkbk -WorksheetName "MG-RBAC" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize
}
catch {
    Write-Warning -Message "Cannot Retrieve Management Group Information"
}
## SUBSCRIPTION ########################################################################################################
$allSubs = Get-AzContext -ListAvailable
$subs = @()
$azFramework = @()
$azNetworking = @()
$subRbac = @()
foreach ( $line in $allSubs ) {
    $parentMg = $mgReport | Where-Object { $_.Name -eq $line.Subscription.Id }
    $subs += $line.Subscription | Select-Object -Property Name, ID, TenantId, State
    $azFramework += $line.Subscription | Select-Object @{n = "ResourceType"; e = { "Sub" } }, @{n = "ResourceName"; e = { $_.Name } }, @{n = "ParentName"; e = { "$($parentMg.ParentDisplayName)" } }, @{n = "AzRegion"; e = { "" } }, @{n = "Info"; e = { $_.State } }, @{n = "Id"; e = { $_.Id } }, @{n = "ParentID"; e = { $parentMg.ParentId } }
    $azNetworking += $line.Subscription | Select-Object @{n = "ResourceType"; e = { "Sub" } }, @{n = "ResourceName"; e = { $_.Name } }, @{n = "ParentName"; e = { "" } }, @{n = "AzRegion"; e = { "" } }, @{n = "Info"; e = { $_.State } }, @{n = "Id"; e = { $_.Id } }, @{n = "ParentID"; e = { "" } }
    try {
        $subRbac += Get-AzRoleAssignment -Scope "/subscriptions/$($line.Subscription.Id)" -AzContext $line -ErrorAction Stop | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, RoleDefinitionName, DisplayName, ObjectType, Scope
    }
    catch { 
        Write-Warning -Message "Cannot Retrieve RBAC:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$subs | Export-Excel -Path $wkbk -WorksheetName "Sub" -BoldTopRow -FreezeTopRow -AutoSize
$azFramework | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
$azNetworking | Export-Excel -Path $wkbk -WorksheetName "AzNetworking" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
$subRbac | Export-Excel -Path $wkbk -WorksheetName "RBAC" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
## RESOURCE GROUPS #####################################################################################################
$rgs = @()
$rgsFramework = @()
foreach ( $line in $allSubs ) {
    $subRgs = Get-AzResourceGroup -AzContext $line
    $rgs += $subRgs | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, ResourceGroupName, Location, ResourceId
    $rgsFramework += $subRgs | Select-Object @{n = "ResourceType"; e = { "RG" } }, @{n = "ResourceName"; e = { $_.ResourceGroupName } }, @{n = "ParentName"; e = { $line.Subscription.Name } }, @{n = "AzRegion"; e = { $_.Location } }, @{n = "Info"; e = { "" } }, @{n = "Id"; e = { $_.ResourceId } }, @{n = "ParentID"; e = { $line.Subscription.Id } }
}
$rgs | Export-Excel -Path $wkbk -WorksheetName "RG" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$rgsFramework | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
if ( !$SkipValidation ) {
    Invoke-Item $wkbk
    $result = [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $messageicon)
    if ( $result -eq 0 ) { return }
}
#### NETWORKING ##################### NETWORKING ###################### NETWORKING ##################### NETWORKING ####
## VIRTUAL NETWORK #####################################################################################################
$vnets = @()
$azFramework = @()
$azNetworking = @()
$snets = @()
$azFrameworkSnet = @()
$azNetworkingSnet = @()
foreach ( $line in $allSubs ) {
    ### Virtual Networks
    try {
        $subVnets = Get-AzVirtualNetwork -AzContext $line -ErrorAction Stop
        $vnets += $subVnets | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, ResourceGroupName, Location, @{n = "AddressSpace"; e = { $_.AddressSpace.AddressPrefixes -join "," } }, @{n = "DNS"; e = { $_.DhcpOptions.DnsServers -join "," } }, EnableDdosProtection, @{n = "DdosProtectionPlan"; e = { $_.DdosProtectionPlan.Id } }, @{n = "Peering Name"; e = { $_.VirtualNetworkPeerings.Name -join "," } }, @{n = "Peering State"; e = { $_.VirtualNetworkPeerings.PeeringState -join "," } }, @{n = "Peered Address"; e = { $_.VirtualNetworkPeerings.RemoteVirtualNetworkAddressSpace.AddressPrefixes -join "," } }, Id
        $azFramework += $subVnets | Select-Object @{n = "ResourceType"; e = { "VNet" } }, @{n = "ResourceName"; e = { $_.Name } }, @{n = "ParentName"; e = { $_.ResourceGroupName } }, @{n = "AzRegion"; e = { $_.Location } }, @{n = "Info"; e = { $_.AddressSpace.AddressPrefixes -join "," } }, Id, @{n = "ParentID"; e = { $_.Id.Split("/")[0..4] -join "/" } }
        $azNetworking += $subVnets | Select-Object @{n = "ResourceType"; e = { "VNet" } }, @{n = "ResourceName"; e = { $_.Name } }, @{n = "ParentName"; e = { $line.Subscription.Name } }, @{n = "AzRegion"; e = { $_.Location } }, @{n = "Info"; e = { $_.AddressSpace.AddressPrefixes -join "," } }, Id, @{n = "ParentID"; e = { $line.Subscription.Id } }
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Virtual Network:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
        continue
    }

    ### Subnets
    foreach ( $vnet in $subVnets ) {
        try {
            $subSnets = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -AzContext $line -ErrorAction Stop
            $snets += $subSnets | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, @{n = "VNet"; e = { $vnet.Name } }, Name, @{n = "AddressPrefix"; e = { $_.AddressPrefix } }, @{n = "NatGateway"; e = { $_.NatGateway.Id } }, @{n = "NetworkSecurityGroup"; e = { $_.NetworkSecurityGroup.Id } }, @{n = "RouteTable"; e = { $_.RouteTable.Id } }, Id
            $azFrameworkSnet += $subSnets | Select-Object @{n = "ResourceType"; e = { "Subnet" } }, @{n = "ResourceName"; e = { $_.Name } }, @{n = "ParentName"; e = { $vnet.Name } }, @{n = "AzRegion"; e = { "" } }, @{n = "Info"; e = { $_.AddressPrefix } }, Id, @{n = "ParentID"; e = { $vnet.Id } }
            $azNetworkingSnet += $subSnets | Select-Object @{n = "ResourceType"; e = { "Subnet" } }, @{n = "ResourceName"; e = { $_.Name } }, @{n = "ParentName"; e = { $vnet.Name } }, @{n = "AzRegion"; e = { "" } }, @{n = "Info"; e = { $_.AddressPrefix } }, Id, @{n = "ParentID"; e = { $vnet.Id } }
        }
        catch {
            Write-Warning -Message "Cannot Retrieve Subnets:"
            Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"    
            Write-Warning -Message "  - Virtual Network: $($vnet.Name)"
        }
    }
}
$vnets | Export-Excel -Path $wkbk -WorksheetName "VNet" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$azFramework | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
$azNetworking | Export-Excel -Path $wkbk -WorksheetName "AzNetworking" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
$snets | Export-Excel -Path $wkbk -WorksheetName "Subnet" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$azFrameworkSnet | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
$azNetworkingSnet | Export-Excel -Path $wkbk -WorksheetName "AzNetworking" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
## ROUTE TABLES ########################################################################################################
$rts = @()
$rtsRoutes = @()
foreach ( $line in $allSubs ) {
    try {
        # RTs
        $myRts = Get-AzRouteTable -AzContext $line -ErrorAction Stop
        $rts += $myRts | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name -join "," } }, Name, ResourceGroupName, Location, ResourceGuid, Id

        # RT Routes
        foreach ( $rt in $myRts ) {
            try {
                $myRoute = Get-AzRouteConfig -RouteTable $rt -AzContext $line -ErrorAction Stop
                $rtsRoutes += $myRoute | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, @{n = "RT"; e = { $rt.Name } }, Name, AddressPrefix, NextHopType, NextHopIpAddress
            }
            catch {
                Write-Warning -Message "Cannot Retrieve Route Table Config:"
                Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"    
                Write-Warning -Message "  - Route Table: $($rt.Name)"
            }
        }
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Route Table:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$rts | Export-Excel -Path $wkbk -WorksheetName "RT" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$rtsRoutes | Export-Excel -Path $wkbk -WorksheetName "RT-Routes" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
## NETWORK SECURITY GROUPS #############################################################################################
$nsgs = @()
$nsgRules = @()
foreach ( $line in $allSubs ) {
    try {
        # NSGs
        $myNsgs = Get-AzNetworkSecurityGroup -AzContext $line -ErrorAction Stop
        $nsgs += $myNsgs | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name -join "," } }, Name, ResourceGroupName, Location, ResourceGuid, Id

        # NSG Rules
        foreach ( $nsg in $myNsgs ) {
            try {
                $myRules = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg -AzContext $line -ErrorAction Stop
                $nsgRules += $myRules | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, @{n = "NSG"; e = { $nsg.Name } }, Name, Description, Protocol, @{n = "SourcePortRange"; e = { $_.SourcePortRange -join "," } }, @{n = "DestinationPortRange"; e = { $_.DestinationPortRange -join "," } }, @{n = "SourceAddressPrefix"; e = { $_.SourceAddressPrefix -join "," } }, @{n = "DestinationAddressPrefix"; e = { $_.DestinationAddressPrefix -join "," } }, @{n = "SourceApplicationSecurityGroups"; e = { $_.SourceApplicationSecurityGroups -join "," } }, @{n = "DestinationApplicationSecurityGroups"; e = { $_.DestinationApplicationSecurityGroups -join "," } }, Access, Priority, Direction
            }
            catch {
                Write-Warning -Message "Cannot Retrieve Network Security Group Rules:"
                Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"    
                Write-Warning -Message "  - Network Security Group: $($nsg.Name)"
            }
        }
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Network Security Groups:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$nsgs | Export-Excel -Path $wkbk -WorksheetName "NSG" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$nsgRules | Export-Excel -Path $wkbk -WorksheetName "NSG-Rules" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
Export-Excel -Path $wkbk -WorksheetName "NSG-Rules" -ConditionalText $(
    New-ConditionalText -Range G:G -ConditionalType Equal -Text * red
    New-ConditionalText -Range G:G -ConditionalType Equal -Text 22 red
    New-ConditionalText -Range G:G -ConditionalType Equal -Text 3389 red
    New-ConditionalText -Range G:G -ConditionalType Equal -Text 5985 red
    New-ConditionalText -Range G:G -ConditionalType Equal -Text 5986 red
)
## PUBLIC IP ###########################################################################################################
$pips = @()
foreach ($line in $allSubs) {
    try {
        $value = Get-AzPublicIpAddress -AzContext $line -ErrorAction Stop
        $pips += $value | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, Name, ResourceGroupName, Location, ResourceGuid, PublicIpAllocationMethod, IpAddress, @{n = "DomainNameLabel"; e = { $_.DnsSettings.DomainNameLabel } }, @{n = "IpConfiguration"; e = { $_.IpConfiguration.Id } }, Id
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Public IP Addresses:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"        
    }
}
$pips | Export-Excel -Path $wkbk -WorksheetName "PubIP" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
Export-Excel -Path $wkbk -WorksheetName "PubIP" -ConditionalText $(
    New-ConditionalText -Range G:G -ConditionalType Equal -Text "Not Assigned" green
)
if ( !$SkipValidation ) {
    Invoke-Item $wkbk
    $result = [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $messageicon)
    if ( $result -eq 0 ) { return }
}
#### COMPUTE & STORAGE ############ COMPUTE & STORAGE ############ COMPUTE & STORAGE ############ COMPUTE & STORAGE ####
## RECOVERY SERVICES VAULT #############################################################################################
$rsvs = @()
$rsvPolicies = @()
$azFramework = @()
foreach ($line in $allSubs) {
    # Vaults
    $myRsvs = Get-AzRecoveryServicesVault -AzContext $line
    $rsvs += $myRsvs | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, Name, ResourceGroupName, Location, Type, ID
    $azFramework += $myRsvs | Select-Object @{n = "ResourceType"; e = { "Vault" } }, @{n = "ResourceName"; e = { $_.Name } }, @{n = "ParentName"; e = { $_.ResourceGroupName } }, @{n = "AzRegion"; e = { $_.Location } }, @{n = "Info"; e = { $_.Type } }, Id, @{n = "ParentID"; e = { $line.Subscription.Id } }
    
    # Backup Policies
    foreach ($rsv in $myRsvs) {
        $policies = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $rsv.Id -AzContext $line
        $rsvPolicies += $policies | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, @{n = "VaultName"; e = { $rsv.Name } }, Name, WorkloadType, SnapshotRetentionInDays, @{n = "DailySchedule"; e = { $_.RetentionPolicy.IsDailyScheduleEnabled } }, @{n = "DailyRetention"; e = { $_.RetentionPolicy.DailySchedule.DurationCountInDays } }, @{n = "WeeklySchedule"; e = { $_.RetentionPolicy.IsWeeklyScheduleEnabled } }, @{n = "WeeklyRetention"; e = { $_.RetentionPolicy.WeeklySchedule.DurationCountInWeeks } }, @{n = "MonthlySchedule"; e = { $_.RetentionPolicy.IsMonthlyScheduleEnabled } }, @{n = "MonthlyRetention"; e = { $_.RetentionPolicy.MonthlySchedule.DurationCountInMonths } }, @{n = "YearlySchedule"; e = { $_.RetentionPolicy.IsYearlyScheduleEnabled } }, @{n = "YearlyRetention"; e = { $_.RetentionPolicy.YearlySchedule.DurationCountInYears } }, Id, @{n = "ParentID"; e = { $rsv.Id } }    
    }
}
$rsvs | Export-Excel -Path $wkbk -WorksheetName "RecoveryVault" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$azFramework | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
$rsvPolicies | Export-Excel -Path $wkbk -WorksheetName "RV-BackupPolicies" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
Export-Excel -Path $wkbk -WorksheetName "RV-BackupPolicies" -ConditionalText $(
    New-ConditionalText -Range E2:E999 -ConditionalType GreaterThan -Text "7" red
    New-ConditionalText -Range G2:G999 -ConditionalType GreaterThan -Text "7" red
    New-ConditionalText -Range I2:I999 -ConditionalType GreaterThan -Text "4" red
    New-ConditionalText -Range K2:K999 -ConditionalType GreaterThan -Text "12" red
    New-ConditionalText -Range M2:M999 -ConditionalType GreaterThan -Text "1" red
)
## STORAGE ACCOUNT #####################################################################################################
$storageaccts = @()
foreach ($line in $allSubs) {
    try {
        $value = Get-AzStorageAccount -AzContext $line -ErrorAction Stop
        $storageaccts += $value | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, StorageAccountName, ResourceGroupName, PrimaryLocation, Kind, AccessTier, EnableHttpsTrafficOnly
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Storage Accounts:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$storageaccts | Export-Excel -Path $wkbk -WorksheetName "StorageAccount" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
## VIRTUAL MACHINE #####################################################################################################
$vms = @()
foreach ($line in $allSubs) {
    try {
        $value = Get-AzVM -AzContext $line -ErrorAction Stop
        $vms += $value | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, Name, ResourceGroupName, Location, @{n = "VMSize"; e = { $_.HardwareProfile.VmSize } }, @{n = "OsType"; e = { $_.StorageProfile.OsDisk.OsType } }, @{n = "ImageType"; e = { $_.StorageProfile.ImageReference.Offer } }, @{n = "Image"; e = { $_.StorageProfile.ImageReference.Sku } }, @{n = "DiskName"; e = { $_.StorageProfile.OsDisk.Name } }, Id
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Virtual Machines:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$vms | Export-Excel -Path $wkbk -WorksheetName "VM" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
## DISKS ###############################################################################################################
$disks = @()
foreach ($line in $allSubs) {
    try {
        $value = Get-AzDisk -AzContext $line -ErrorAction Stop
        $disks += $value | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, Name, ResourceGroupName, DiskSizeGB, DiskState, DiskIOPSReadWrite, DiskMBpsReadWrite, Encryption, Location, Sku, ManagedBy, UniqueID, Id 
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Managed Disks:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$disks | Export-Excel -Path $wkbk -WorksheetName "Disks" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
Export-Excel -Path $wkbk -WorksheetName "Disks" -ConditionalText $(
    New-ConditionalText -Range E2:E999 -ConditionalType Equal -Text "Unattached" green
)
if ( !$SkipValidation ) {
    Invoke-Item $wkbk
    $result = [System.Windows.MessageBox]::Show($Messageboxbody, $MessageboxTitle, $ButtonType, $messageicon)
    if ( $result -eq 0 ) { return }
}
#### GOVERNANCE ###################### GOVERNANCE #################### GOVERNANCE ###################### GOVERNANCE ####
## LOG ANALYTICS #######################################################################################################
$laws = @()
$azFramework = @()
foreach ($line in $allSubs) {
    try {
        $value = Get-AzOperationalInsightsWorkspace -AzContext $line -ErrorAction Stop
        $laws += $value | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name -join "," } }, Name, ResourceGroupName, Location, Sku, @{n = "RetentionInDays"; e = { $_.retentionInDays } }, ResourceId
        $azFramework += $value | Select-Object @{n = "ResourceType"; e = { "LA" } }, @{n = "ResourceName"; e = { $_.Name } }, @{n = "ParentName"; e = { $_.ResourceGroupName } }, @{n = "AzRegion"; e = { $_.Location } }, @{n = "Info"; e = { $_.Sku } }, @{n = "Id"; e = { $_.ResourceId } }, @{n = "ParentID"; e = { $line.Subscription.Id } }
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Log Analytics Workspaces:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$laws | Export-Excel -Path $wkbk -WorksheetName "LogAnalytics" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$azFramework | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
Export-Excel -Path $wkbk -WorksheetName "LogAnalytics" -ConditionalText $(
    New-ConditionalText -Range F2:F999 -ConditionalType GreaterThanOrEqual -Text "90" green
)
## AUTOMATION ACCOUNT ##################################################################################################
$autoaccts = @()
$azFramework = @()
foreach ($line in $allSubs) {
    try {
        $value = Get-AzAutomationAccount -AzContext $line -ErrorAction Stop
        $autoaccts += $value | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, AutomationAccountName, ResourceGroupName, Location
        $azFramework += $value | Select-Object @{n = "ResourceType"; e = { "Auto" } }, @{n = "ResourceName"; e = { $_.AutomationAccountName } }, @{n = "ParentName"; e = { $_.ResourceGroupName } }, @{n = "AzRegion"; e = { $_.Location } }, @{n = "Info"; e = { "" } }, @{n = "Id"; e = { ("/subscriptions/" + $line.id + "/resourceGroups/" + $_.ResourceGroupName + "/providers/Microsoft.Automation/" + $_.AutomationAccountName) } }, @{n = "ParentID"; e = { $line.Subscription.Id } }
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Automation Accounts:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$autoaccts | Export-Excel -Path $wkbk -WorksheetName "Auto" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$azFramework | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
## KEY VAULT ###########################################################################################################
$kvs = @()
$azFramework = @()
foreach ($line in $allSubs) {
    try {
        $value = Get-AzKeyVault -AzContext $line -ErrorAction Stop
        foreach ( $kvalue in $value ) {
            $kv = Get-AzKeyVault -ResourceGroupName $kvalue.ResourceGroupName -VaultName $kvalue.VaultName -AzContext $line
            $kvs += $kv | Select-Object @{n = "Subscription"; e = { $line.Subscription.Name } }, VaultName, ResourceGroupName, Location, Sku, ResourceId
            $azFramework += $kv | Select-Object @{n = "ResourceType"; e = { "KV" } }, @{n = "ResourceName"; e = { $_.VaultName } }, @{n = "ParentName"; e = { $_.ResourceGroupName } }, @{n = "AzRegion"; e = { $_.Location } }, @{n = "Info"; e = { "" } }, @{n = "Id"; e = { $_.ResourceId } }, @{n = "ParentID"; e = { $line.Subscription.Id } }
        }
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Key Vaults:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$kvs | Export-Excel -Path $wkbk -WorksheetName "KeyVault" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$azFramework | Export-Excel -Path $wkbk -WorksheetName "AzFramework" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -MoveToStart -Append
Export-Excel -Path $wkbk -WorksheetName "KeyVault" -ConditionalText $(
    New-ConditionalText -Range E:E -ConditionalType Equal -Text "Premium" green
)
## POLICY ##############################################################################################################
$policies = @()
$policyStates = @()
foreach ($line in $allSubs) {
    try {
        #Policy Assignments
        $value = Get-AzPolicyAssignment -AzContext $line -ErrorAction Stop
        $policies += $value | Select-Object -Property @{n = "PolicyID"; e = { $_.Name } }, @{n = "DisplayName"; e = { $_.Properties.displayName } }, @{n = "Enforcement"; e = { $_.Properties.enforcementMode } }, @{n = "Scope"; e = { $_.Properties.scope } }, ResourceId
        #Policy States
        $value = Get-AzPolicyState -AzContext $line -ErrorAction Stop
        $policyStates += $value | Select-Object -Property @{n = "PolicyID"; e = { $_.PolicyAssignmentName } }, PolicyDefinitionId, IsCompliant, ComplianceState, PolicyDefinitionAction, PolicyDefinitionCategory, SubscriptionId, PolicyAssignmentScope, ResourceId
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Azure Policy Information:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$policies | Export-Excel -Path $wkbk -WorksheetName "Policy" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$policyStates | Export-Excel -Path $wkbk -WorksheetName "PolicyState" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
## SECURITY CENTER #####################################################################################################
$secContacts = @()
$secAutoProv = @()
$secWorkspace = @()
$secPricing = @()
$secTasks = @()
foreach ($line in $allSubs) {
    # Contacts
    try {
        $v1 = Get-AzSecurityContact -AzContext $line -ErrorAction Stop
        $secContacts += $v1 | Select-Object -Property @{n = "Subscription"; e = { $line.Subscription.Name } }, @{n = "ContactName"; e = { $_.Name } }, Email, Phone
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Azure Security Contact Information:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
    # Provisioning Settings
    try {
        $v2 = Get-AzSecurityAutoProvisioningSetting -AzContext $line -ErrorAction Stop
        $secAutoProv += $v2 | Select-Object -Property @{n = "Subscription"; e = { $line.Subscription.Name } }, @{n = "AutoProvisioningName"; e = { $_.Name } }, Id
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Azure Security Auto Provisioning Information:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
    # Workspace Settings
    try {
        $v3 = Get-AzSecurityWorkspaceSetting -AzContext $line -ErrorAction Stop
        $secWorkspace += $v3 | Select-Object -Property @{n = "Subscription"; e = { $line.Subscription.Name } }, @{n = "WorkspaceName"; e = { $_.Name } }, Scope, WorkspaceId
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Azure Security Workspace Setting Information:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
    # Pricing
    try {
        $v4 = Get-AzSecurityPricing -AzContext $line -ErrorAction Stop
        $secPricing += $v4 | Select-Object -Property @{n = "Subscription"; e = { $line.Subscription.Name } }, Name, PricingTier
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Azure Security Pricing Information:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
    # Tasks
    try {
        $v5 = Get-AzSecurityTask -AzContext $line -ErrorAction Stop
        $secTasks += $v5 | Select-Object -Property @{n = "SubscriptionID"; e = { $line.Subscription.Id } }, @{n = "Subscription"; e = { $line.Subscription.Name } }, RecommendationType, ResourceId
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Azure Security Task Information:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
}
$secContacts | Export-Excel -Path $wkbk -WorksheetName "ASC-Contact" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$secAutoProv | Export-Excel -Path $wkbk -WorksheetName "ASC-AutoProv" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$secWorkspace | Export-Excel -Path $wkbk -WorksheetName "ASC-Workspace" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$secPricing | Export-Excel -Path $wkbk -WorksheetName "ASC-Pricing" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
$secTasks | Export-Excel -Path $wkbk -WorksheetName "ASC-Tasks" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
## ADVISOR #############################################################################################################
Import-Module Az.Advisor
$advisors = @()
foreach ($line in $allSubs) {
    try {
        $advisor = Get-AzAdvisorRecommendation -AzContext $line -ErrorAction Stop
        $advisors += $advisor | Select-Object -Property @{n = "SubscriptionID"; e = { $line.Subscription.Id } }, @{n = "Subscription"; e = { $line.Subscription.Name } }, Category, Impact, ImpactedValue, ResourceId
    }
    catch {
        Write-Warning -Message "Cannot Retrieve Azure Advisor Information:"
        Write-Warning -Message "- Subscription: $($line.Subscription.Name) ($($line.Subscription.Id))"
    }
    #$wshell = New-Object -ComObject Wscript.Shell
    #$wshell.Popup("There are Azure Advisor Recommendations available. You will need to use the Portal to download the complete report.",0,"Azure Advisor",0x0)
}
$advisors | Export-Excel -Path $wkbk -WorksheetName "Advisor" -BoldTopRow -AutoFilter -FreezeTopRow -AutoSize -Append
Export-Excel -Path $wkbk -WorksheetName "Advisor" -ConditionalText $(
    New-ConditionalText -Range D:D -ConditionalType Equal -Text High red
)
########################################################################################################################
Disconnect-AzAccount
$wshell = New-Object -ComObject Wscript.Shell
$wshell.Popup("The Azure Envioronment Report script has completed.", 0, "***COMPLETE***", 0x0)
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
