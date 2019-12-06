## script exports users from Azure AD creating an excel
##
## variables: set via prompts during execution
##
##
## created/modified: 201908
## https://ms.bahnhacker.us | https://github.bahnhacker.us
## contact: https://twitter.com/bahnhacker | https://www.linkedin.com/in/bpstephenson
########################################################################################################################
########################################################################################################################

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

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
Function Select-FolderDialog  ## Gets the path for the unzipped files
{
    param([string]$Description="Select the AD-DS_Deployment Folder",[string]$RootFolder="Desktop")

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
$Path = Select-FolderDialog

## PS variables
$Date = Get-Date -f yyyyMM


########################################################################################################################

#Install-Module MSOnline


try{
## Create an Excel COM Object
$excel = New-Object -ComObject excel.application
}catch{
    Write-Host "Something went wrong in creating excel. Make sure you have MSOffice installed to access MSExcel. Please try running the script again. `n" -ForegroundColor Yellow
}

## Create a Workbook
$workbook = $excel.Workbooks.Add()


## Connect to Msol Service (To access Azure Active Directory)
Connect-MsolService

$users = Get-MsolUser -All

## Function to create Azure AD User List Worksheet
function Create-AzureUserListWorksheet {

        Write-Host "Creating the Azure Active Directory User List worksheet..." -ForegroundColor Green
        
        ## Adding worksheet
        $workbook.Worksheets.Add()

        ## Creating the "Virtual Machine" worksheet and naming it
        $AzureADUserListWorksheet = $workbook.Worksheets.Item(1)
        $AzureADUserListWorksheet.Name = 'Azure AD User List'

        ## Headers for the worksheet
        $AzureADUserListWorksheet.Cells.Item(1,1) = 'User Display Name'
        $AzureADUserListWorksheet.Cells.Item(1,2) = 'User Object ID'
        $AzureADUserListWorksheet.Cells.Item(1,3) = 'User Type'
        $AzureADUserListWorksheet.Cells.Item(1,4) = 'User Principle Name'
        $AzureADUserListWorksheet.Cells.Item(1,5) = 'User Role Name'
        $AzureADUserListWorksheet.Cells.Item(1,6) = 'User Role Description'
        
        ## Cell Counter
        $row_counter = 3
        $column_counter = 1

        ## Iterating over the Virtual Machines under the subscription
        
        foreach ($users_iterator in $users){

            $user_displayname = $users_iterator.displayname
            $user_object_id = $users_iterator.objectid
            $user_type = $users_iterator.UserType
            $user_principal_name = $users_iterator.userprincipalname

            if($user_object_id -ne $null){
                $user_role_name = (Get-MsolUserRole -ObjectId $user_object_id).name
                $user_role_description = (Get-MsolUserRole -ObjectId $user_object_id).Description
            }else{
                $user_role_name = "NULL"
                $user_role_description = "NULL"
            }

            Write-host "Extracting information for user: " $user_displayname

            $AzureADUserListWorksheet.Cells.Item($row_counter,$column_counter++) = $user_displayname
            $AzureADUserListWorksheet.Cells.Item($row_counter,$column_counter++) = $user_object_id.tostring()
            $AzureADUserListWorksheet.Cells.Item($row_counter,$column_counter++) = $user_type
            $AzureADUserListWorksheet.Cells.Item($row_counter,$column_counter++) = $user_principal_name
            $AzureADUserListWorksheet.Cells.Item($row_counter,$column_counter++) = $user_role_name
            $AzureADUserListWorksheet.Cells.Item($row_counter,$column_counter++) = $user_role_description

            $row_counter = $row_counter + 1
            $column_counter = 1

        }
}


## Calling function
Create-AzureUserListWorksheet


## Checking if the Inventory.xlsx already exists
if(Test-Path $Path\AzureADUserList_$Date.xlsx){
    Write-Host "$Path\AzureADUserList_$Date.xlsx already exitst. Deleting the current file and creating a new one. `n" -ForegroundColor Yellow
    Remove-Item $Path\AzureADUserList_$Date.xlsx
    ## Saving the workbook/excel file
    $workbook.SaveAs("$Path\AzureADUserList_$Date.xlsx")
}else {
    ## Saving the workbook/excel file
    $workbook.SaveAs("$Path\AzureADUserList_$Date.xlsx")
}


Write-Host "File is saved as - $Path\AzureADUserList_$Date.xlsx `n" -ForegroundColor Green



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