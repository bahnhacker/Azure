## script imports users and groups from csv.
##
## variables: set via prompts during execution
##
##
## created/modified: 202001
## https://ms.bahnhacker.us | https://github.bahnhacker.us
## contact: https://twitter.com/bahnhacker | https://www.linkedin.com/in/bpstephenson
########################################################################################################################
########################################################################################################################

Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force

## self-elevate the script if required
<#
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] $env:USERNAME)) {
 if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
  $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
  Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
  Exit
 }
}
#>


########################################################################################################################

## PS variables
$date = Get-Date -f yyyy-MM-dd
$datefull = Get-Date -f yyyyMMdd-hhmm

########################################################################################################################
## required PSmodules
if (Get-Module -ListAvailable -Name MSOnline) {
    Connect-MsolService
} 
else {
    Write-Host "Installing the MSOnline Powershell Module"
    Install-Module MSOnline -AllowClobber -Scope AllUsers
    Connect-MsolService
    }

if (Get-Module -ListAvailable -Name AzureAD) {
    Import-Module AzureAD
} 
else {
    Write-Host "Installing the AzureAD Powershell Module"
    Install-Module AzureAD -AllowClobber -Scope AllUsers
}

########################################################################################################################
## creates import group
$importgroup = ("Import-" + "$datefull")

New-MsolGroup -DisplayName "$importgroup" -Description "This group contains all users imported on $date"
$grpobjid = Get-MsolGroup | Where-Object {$_.DisplayName -eq “$importgroup”} | select -Property ObjectId

## creates password file
$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = Read-Host "input the password to be used for ALL imported accounts"

## imports the users from csv
$usercsv = Read-Host "provide the FULL path\name.csv for the users file"

Import-Csv $usercsv | ForEach-Object {
New-MsolUser -DisplayName $_.DisplayName -FirstName $_.FirstName -LastName $_.LastName -UserPrincipalName $_.UserPrincipalName -Department $_.Department -StreetAddress $_.StreetAddress -City $_.city -State $_.State -Country $_.Country -Office $_.Office -MobilePhone $_.MobilePhone -Password $PasswordProfile.Passwor
$displayname = $_.DisplayName
$usrobjid = Get-MsolUser | Where-Object {$_.DisplayName -eq “$displayname”} | select -Property ObjectId
Add-MsolGroupMember -GroupObjectId $grpobjid.ObjectId -GroupMemberObjectId $usrobjid.ObjectId -GroupMemberType User 
}

## imports the groups from csv
$groupscsv = Read-Host "provide the FULL path\name.csv for the groups file"

Import-Csv $groupscsv | ForEach-Object {
New-MsolGroup -DisplayName $_.DisplayName -Description $_.Description
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