## script creates network resources incl vnet, subnet and nsg.
##
## variables: modify variables accordingly
##
## 
## created/modified: 201906
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

## script variables
#### Naming Convention
$bus = "<<enter Business identifier>>" ## Short business/organization name
$env = "<<enter Environment identifier>>" ## Prod/PreProd/Stage/QA/Test/Dev or service short name
$azreg = "<<enter Azure azregion identifier>>" ## ie. EastUS2 (eus2)
$ipoct1 = "<<enter first octet of IP space for environment" ## ie. 10.--.--.--
$ipoct2 = "<<enter second octet of IP space for environment" ## ie. --.11.--.--


########################################################################################################################

## Check for/Create RSG for network items
$rg1 = ($bus + "-" + $azreg + "-" + $env + "-networking-rg")

Get-AzureRmResourceGroup -Name $rg1 -ErrorVariable notPresent -ErrorAction SilentlyContinue
if ($notPresent)
{
 New-AzureRmResourceGroup $rg1 -location $azreg 
}
else
{
 Write-Host "$rg1 exists! Continuing on vNet creation."
}

## Create NSGs
$nsg1 = New-AzureRmNetworkSecurityGroup -Name ($env + "-Infra-" + $azreg +"-nsg") -ResourceGroupName $rg1 -Location $azreg
$nsg2 = New-AzureRmNetworkSecurityGroup -Name ($env + "-App-" + $azreg +"-nsg") -ResourceGroupName $rg1 -Location $azreg
$nsg3 = New-AzureRmNetworkSecurityGroup -Name ($env + "-DB-" + $azreg +"-nsg") -ResourceGroupName $rg1 -Location $azreg
$nsg4 = New-AzureRmNetworkSecurityGroup -Name ($env + "-DMZ-" + $azreg +"-nsg") -ResourceGroupName $rg1 -Location $azreg

 
## Create Subnet configs and associate with NSGs
$GatewaySubnet = New-AzureRmVirtualNetworkSubnetConfig -name "GatewaySubnet" -AddressPrefix ($ipoct1 + "." + $ipoct2 + ".0.0/27") -NetworkSecurityGroup $nsg1
$Infra_Tier = New-AzureRmVirtualNetworkSubnetConfig -name ($env + "-Infra-" + $azreg) -AddressPrefix ($ipoct1 + "." + $ipoct2 + ".2.0/23") -NetworkSecurityGroup $nsg1
$App_Tier = New-AzureRmVirtualNetworkSubnetConfig -name ($env + "-App-" + $azreg) -AddressPrefix ($ipoct1 + "." + $ipoct2 + ".4.0/23") -NetworkSecurityGroup $nsg2
$DB_Tier = New-AzureRmVirtualNetworkSubnetConfig -name ($env + "-DB-" + $azreg) -AddressPrefix ($ipoct1 + "." + $ipoct2 + ".6.0/23") -NetworkSecurityGroup $nsg3
$DMZ_Tier = New-AzureRmVirtualNetworkSubnetConfig -name ($env + "-DMZ-" + $azreg) -AddressPrefix ($ipoct1 + "." + $ipoct2 + ".8.0/23") -NetworkSecurityGroup $nsg4
 

## Create vnet Subnets and NSGs in places
$vnet = ($bus + "-" + $azreg + "-" + $env + "-vnet")
$vnetIP = ($ipoct1 + "." + $ipoct2 + ".0.0/16")

New-AzureRmVirtualNetwork -Name $vnet -Location $azreg -ResourceGroupName $rg1 -AddressPrefix $vnetIP -Subnet $GatewaySubnet,$Infra_Tier,$App_Tier,$DB_Tier,$DMZ_Tier -AsJob



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