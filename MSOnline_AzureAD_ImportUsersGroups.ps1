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
## imports the users csv
Write-Host "select the USERS.csv file..." -ForegroundColor Green

Function Get-FileName($InitialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = $initialDirectory
  $OpenFileDialog.filter = "CSV (*.csv) | *.csv"
  $OpenFileDialog.ShowDialog() | Out-Null
}

$userscsv = Get-FileName

$users = Import-Csv "$userscsv"
$users | ForEach-Object {
New-MsolUser -DisplayName $_.DisplayName -FirstName $_.FirstName -LastName $_.LastName -UserPrincipalName $_.UserPrincipalName -Department $_.Department -StreetAddress $_.StreetAddress -City $_.city -State $_.State -Country $_.Country -Office $_.Office -MobilePhone $_.MobilePhone
}

########################################################################################################################
## imports the groups csv
Write-Host "select the GROUPS.csv file..." -ForegroundColor Green

Function Get-FileName($InitialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

  $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = $initialDirectory
  $OpenFileDialog.filter = "CSV (*.csv) | *.csv"
  $OpenFileDialog.ShowDialog() | Out-Null
}

$groupscsv = Get-FileName

$groups = Import-Csv "$groupscsv"
$groups | ForEach-Object {
New-MsolGroup -DisplayName $_.DisplayName -Description $_.Description -ManagedBy $_.ManagedBy
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