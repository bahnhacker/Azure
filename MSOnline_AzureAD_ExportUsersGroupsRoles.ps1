## script exports users and groups from Azure AD creating a combined excel and individual csv files for each object.
## the users worksheet includes any roles assigned to a user. the export includes csv files for group members.
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

## custom variables 
$domain = Read-Host -Prompt "provide a shortname for the domain"

Function Select-FolderDialog
{
    param([string]$Description="select the location where the output file is to be stored",[string]$RootFolder="Desktop")

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

## PS variables
$date = Get-Date -f yyyyMM


########################################################################################################################
#Install-Module MSOnline

## connect to msol service
Connect-MsolService

$filename = ("$date" + "-AzAD-" + "$domain")
$path = New-Item -ItemType "directory" -Path "$select_path\$filename" ## creates root

## create an excel
try{
$excel = New-Object -ComObject excel.application
}catch{
    Write-Host "Something went wrong in creating excel. Make sure you have MSOffice installed to access MSExcel. Please try running the script again. `n" -ForegroundColor Yellow
}

## create a workbook
$workbook = $excel.Workbooks.Add()
$exportfilename = ("$date" + "_" + "$domain" + "_" + "AzureAD_UsersGroupsRoles.xlsx")


########################################################################################################################
## creates all users csv
$allusers = ("$path" + "\" + "$date" + "-" + "$domain" + "-AzAD-AllUsersReport.csv")
Get-MSOLUser -All | Select-Object DisplayName, FirstName, LastName, SignInName, userprincipalname, Department, StreetAddress, City, State, Country, Office, MobilePhone | Export-Csv $allusers

## gets users
$users = Get-MsolUser -All

## function to create azure ad user list worksheet
function Create-UserWorksheet {

        Write-Host "creating the azure ad user worksheet..." -ForegroundColor Green
        
        ## adding worksheet
        $workbook.Worksheets.Add()

        ## creating the user worksheet and naming it
        $UsersWorksheet = $workbook.Worksheets.Item(1)
        $UsersWorksheet.Name = 'UsersRoles'

        ## Headers for the worksheet
        $UsersWorksheet.Cells.Item(1,1) = 'User Display Name'
        $UsersWorksheet.Cells.Item(1,2) = 'FirstName'
        $UsersWorksheet.Cells.Item(1,3) = 'LastName'

        $UsersWorksheet.Cells.Item(1,4) = 'SignInName'
        $UsersWorksheet.Cells.Item(1,5) = 'User Principle Name'
        $UsersWorksheet.Cells.Item(1,6) = 'User Object ID'

        $UsersWorksheet.Cells.Item(1,7) = 'User Type'
        $UsersWorksheet.Cells.Item(1,8) = 'WhenCreated'
        $UsersWorksheet.Cells.Item(1,9) = 'LastPasswordChangeTimestamp'
        $UsersWorksheet.Cells.Item(1,10) = 'User Role Name'
        $UsersWorksheet.Cells.Item(1,11) = 'User Role Description'

        $UsersWorksheet.Cells.Item(1,12) = 'Department'
        $UsersWorksheet.Cells.Item(1,13) = 'StreetAddress'
        $UsersWorksheet.Cells.Item(1,14) = 'City'
        $UsersWorksheet.Cells.Item(1,15) = 'State'
        $UsersWorksheet.Cells.Item(1,16) = 'Country'
        $UsersWorksheet.Cells.Item(1,17) = 'Office'
        $UsersWorksheet.Cells.Item(1,18) = 'MobilePhone'

        ## cell counter
        $row_counter = 3
        $column_counter = 1

        ## iterating the users under the subscription
        foreach ($users_iterator in $users){
            $user_displayname = $users_iterator.displayname
            $user_FirstName = $users_iterator.FirstName
            $user_LastName = $users_iterator.LastName

            $user_SignInName = $users_iterator.SignInName
            $user_principal_name = $users_iterator.userprincipalname        
            $user_object_id = $users_iterator.objectid

            $user_type = $users_iterator.UserType
            $user_WhenCreated = $users_iterator.WhenCreated
            $user_LastPasswordChangeTimestamp = $users_iterator.LastPasswordChangeTimestamp
            if($user_object_id -ne $null){
                $user_role_name = (Get-MsolUserRole -ObjectId $user_object_id).name
                $user_role_description = (Get-MsolUserRole -ObjectId $user_object_id).Description
            }else{
                $user_role_name = "NULL"
                $user_role_description = "NULL"
            }

            $user_Department = $users_iterator.Department
            $user_StreetAddress = $users_iterator.StreetAddress
            $user_City = $users_iterator.City
            $user_State = $users_iterator.State
            $user_Country = $users_iterator.Country
            $user_Office = $users_iterator.Office
            $user_MobilePhone = $users_iterator.MobilePhone

            Write-host "extracting information for user: " $user_displayname

            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_displayname
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_FirstName
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_LastName

            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_SignInName
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_principal_name
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_object_id.tostring()

            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_type
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_WhenCreated
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_LastPasswordChangeTimestamp
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_role_name
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_role_description

            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_Department
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_StreetAddress
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_City
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_State
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_Country
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_Office
            $UsersWorksheet.Cells.Item($row_counter,$column_counter++) = $user_MobilePhone

            $exportcsv = ("$path" + "\" + "USR-" + "$user_object_id"+ ".csv")
            Get-MsolUser -ObjectId $user_object_id | select * | Export-CSV "$exportcsv" –NoTypeInformation 
            
            $row_counter = $row_counter + 1
            $column_counter = 1
        }
}


########################################################################################################################
## creates all group csv
$allgroups = ("$path" + "\" + "$date" + "-" + "$domain" + "-AzAD-AllGroupsReport.csv")
Get-MsolGroup -All | Select-Object CommonName, Description, DisplayName, EmailAddress, GroupType, ManagedBy | Export-Csv $allgroups

## gets users
$groups = Get-MsolGroup -All

## function to create azure ad user list worksheet
function Create-GroupWorksheet {

        Write-Host "creating the azure ad group worksheet..." -ForegroundColor Green
        
        ## adding worksheet
        $workbook.Worksheets.Add()

        ## creating the user worksheet and naming it
        $GroupsWorksheet = $workbook.Worksheets.Item(1)
        $GroupsWorksheet.Name = 'Groups'

        ## Headers for the worksheet
        $GroupsWorksheet.Cells.Item(1,1) = 'Common Name'
        $GroupsWorksheet.Cells.Item(1,2) = 'Description'
        $GroupsWorksheet.Cells.Item(1,3) = 'Display Name'
        $GroupsWorksheet.Cells.Item(1,4) = 'Email Address'
        $GroupsWorksheet.Cells.Item(1,5) = 'Group Type'
        $GroupsWorksheet.Cells.Item(1,6) = 'ManagedBy'
        $GroupsWorksheet.Cells.Item(1,7) = 'ObjectId'

        ## cell counter
        $row_counter = 3
        $column_counter = 1

        ## iterating the groups under the subscription
        foreach ($groups_iterator in $groups){
            $group_CommonName = $groups_iterator.CommonName
            $group_Description = $groups_iterator.Description
            $group_DisplayName = $groups_iterator.DisplayName
            $group_EmailAddress = $groups_iterator.EmailAddress
            $group_GroupType = $groups_iterator.GroupType
            $group_ManagedBy = $groups_iterator.ManagedBy
            $group_ObjectId = $groups_iterator.ObjectId

            Write-host "extracting information for group: " $group_DisplayName

            $GroupsWorksheet.Cells.Item($row_counter,$column_counter++) = $group_CommonName
            $GroupsWorksheet.Cells.Item($row_counter,$column_counter++) = $group_Description
            $GroupsWorksheet.Cells.Item($row_counter,$column_counter++) = $group_DisplayName
            $GroupsWorksheet.Cells.Item($row_counter,$column_counter++) = $group_EmailAddress
            $GroupsWorksheet.Cells.Item($row_counter,$column_counter++) = $group_GroupType
            $GroupsWorksheet.Cells.Item($row_counter,$column_counter++) = $group_ManagedBy
            $GroupsWorksheet.Cells.Item($row_counter,$column_counter++) = $group_ObjectId.tostring()

            $exportcsv = ("$path" + "\" + "GRP-" + "$group_ObjectId"+ ".csv")
            Get-MsolGroup -ObjectId $group_ObjectId | select * | Export-CSV "$exportcsv" –NoTypeInformation 
            $exportcsv = ("$path" + "\" + "MBR-" + "$group_ObjectId"+ ".csv")
            Get-MsolGroupMember -GroupObjectId $group_ObjectId | Export-CSV "$exportcsv" –NoTypeInformation 

            $row_counter = $row_counter + 1
            $column_counter = 1
        }
}


########################################################################################################################
## calling function
Create-UserWorksheet
Create-GroupWorksheet

## Saving the excel file
$workbook.SaveAs("$Path\$exportfilename")


Write-Host "files are saved at - $select_path\$filename `n" -ForegroundColor Green



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