## script prompts for vairables then creates the standard/default NSG rules required for ADDS.
## note:
## * the prompt for IP range/scope has been commented out as it failed to except a list as a response.
## * script enables traffic for RDP and ADMT, rules should be disabled immediately following the project.
##
## variables: set via prompts during execution
##
##
## created/modified: 201903
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
$SUBID = Read-Host -Prompt "Input the Subscription ID" ##ID of the Subscription
$NSG = Read-Host -Prompt "Input the name for the EXISTING Network Security Group (NSG) to be modified" ##Name of the Network Security Group
$RG = Read-Host -Prompt "Input the name for the EXISTING Resource Group (RG) associated with the NSG" ##Name of the Resource Group
#$NSG_INT = Read-Host -Prompt "Input the IP range/scope managed WITHIN the NSG"##IP scope or range for resources managed WITHIN the NSG
#$NSG_EXT = Read-Host -Prompt "Input the IP range/scope for resources OUTSIDE the NSG" ##IP scope or range for resources OUTSIDE the NSG

## PS variables
$Date = Get-Date -f yyyyMMddhhmm
$myIP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content

## script variables
#### Source & Destination IP
$INBSRC_IP = "*" #$NSG_EXT
$INBDST_IP = "*" #$NSG_INT
$OBDSRC_IP = "*" #$NSG_INT
$OBDDST_IP = "*" #$NSG_EXT

#### Ports required for Active Directory Domain Services
$DNS_port = "53"
$DCCOM_port = "135"
$DCFRS_TCP_port = "139"
$DCFRS_UDP_port = "138"
$GCS_TCP_port = "3268-3269"
$FRS_port = "445"
$LDAP_UDP_port = "389"
$KDC_port = "88"
$KDCPW_port = "464"
$ADC_port = "49152-65535"
$NTP_port = "123"

$RDP_port = "3389"
$ADMT_port = "1024-65535"


########################################################################################################################

## connects to Azure
Get-AzureRmSubscription -SubscriptionId $SUBID | Select-AzureRmSubscription

## confirms Azure environment
Get-AzureRmContext
Read-Host -Prompt "Please confirm the Azure Subscription selected. Press any key to continue or CTRL+C to quit" 


$SELNSG = Get-AzureRmNetworkSecurityGroup -Name $NSG -ResourceGroupName $RG ## selects nsg to be modified

## inbound Rules
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name DNS_INB -Description "DomainControllers-to-DomainController and Client-to-DomainController operations" -Access Allow -Protocol * -Direction Inbound -Priority 100 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $DNS_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name DCCOM_INB -Description "DomainControllers-to-DomainController and Client-to-DomainController operations" -Access Allow -Protocol * -Direction Inbound -Priority 101 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $DCCOM_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name DCFRS_TCP_INB -Description "(TCP) File Replication Service between DomainControllers" -Access Allow -Protocol Tcp -Direction Inbound -Priority 102 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $DCFRS_TCP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name DCFRS_UDP_INB -Description "(UDP) File Replication Service between DomainControllers" -Access Allow -Protocol Udp -Direction Inbound -Priority 103 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $DCFRS_UDP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name GCS_TCP_INB -Description "Global Catalog from Client-to-DomainController" -Access Allow -Protocol Tcp -Direction Inbound -Priority 104 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $GCS_TCP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name FRS_INB -Description "File Replication Service" -Access Allow -Protocol * -Direction Inbound -Priority 105 -SourceAddressPrefix $INBSRC_IP -SourcePortRange *  -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $FRS_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name LDAP_UDP_INB -Description "LDAP to handle normal queries from Client-to-DomainController" -Access Allow -Protocol Udp -Direction Inbound -Priority 106 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $LDAP_UDP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name KDC_INB -Description "Kerberos authentication/communication" -Access Allow -Protocol * -Direction Inbound -Priority 107 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $KDC_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name KDCPW_INB -Description "Kerberos Password Change" -Access Allow -Protocol * -Direction Inbound -Priority 108 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $KDCPW_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name ADC_INB -Description "ADConnect ports used during the initial configuration and during Password synchronization" -Access Allow -Protocol * -Direction Inbound -Priority 109 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $ADC_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name NTP_INB -Description "Network TIme Protocol Service" -Access Allow -Protocol * -Direction Inbound -Priority 110 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $NTP_port

$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name TMP_RDP_INB -Description "RDP port to allow connectivity. This rule is intended to ONLY be utilized during deployment and should be removed as soon as possible." -Access Allow -Protocol Tcp -Direction Inbound -Priority 900 -SourceAddressPrefix $INBSRC_IP -SourcePortRange $myIP -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $RDP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name TMP_ADMT_INB -Description "Dynamic Port Range for ADMT. This rule is intended to ONLY be utilized during deployment and should be removed as soon as possible." -Access Allow -Protocol * -Direction Inbound -Priority 901 -SourceAddressPrefix $INBSRC_IP -SourcePortRange * -DestinationAddressPrefix $INBDST_IP -DestinationPortRange $ADMT_port


## outbound Rules
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name DNS_OBD -Description "DomainControllers-to-DomainController and Client-to-DomainController operations" -Access Allow -Protocol * -Direction Outbound -Priority 100 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $DNS_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name DCCOM_OBD -Description "DomainControllers-to-DomainController and Client-to-DomainController operations" -Access Allow -Protocol * -Direction Outbound -Priority 101 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $DCCOM_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name DCFRS_TCP_OBD -Description "(TCP) File Replication Service between DomainControllers" -Access Allow -Protocol Tcp -Direction Outbound -Priority 102 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $DCFRS_TCP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name DCFRS_UDP_OBD -Description "(UDP) File Replication Service between DomainControllers" -Access Allow -Protocol Udp -Direction Outbound -Priority 103 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $DCFRS_UDP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name GCS_TCP_OBD -Description "Global Catalog from Client-to-DomainController" -Access Allow -Protocol Tcp -Direction Outbound -Priority 104 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $GCS_TCP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name FRS_OBD -Description "File Replication Service" -Access Allow -Protocol * -Direction Outbound -Priority 105 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $FRS_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name LDAP_UDP_OBD -Description "LDAP to handle normal queries from Client-to-DomainController" -Access Allow -Protocol Udp -Direction Outbound -Priority 106 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $LDAP_UDP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name KDC_OBD -Description "Kerberos authentication/communication" -Access Allow -Protocol * -Direction Outbound -Priority 107 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $KDC_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name KDCPW_OBD -Description "Kerberos Password Change" -Access Allow -Protocol * -Direction Outbound -Priority 108 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $KDCPW_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name ADC_OBD -Description "ADConnect ports used during the initial configuration and during Password synchronization" -Access Allow -Protocol * -Direction Outbound -Priority 109 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $ADC_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name NTP_OBD -Description "Network TIme Protocol Service" -Access Allow -Protocol * -Direction Outbound -Priority 110 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRang $NTP_port

$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name TMP_RDP_ODB -Description "RDP port to allow connectivity. This rule is intended to ONLY be utilized during deployment and should be removed as soon as possible." -Access Allow -Protocol Tcp -Direction Outbound -Priority 900 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $RDP_port
$SELNSG | Add-AzureRmNetworkSecurityRuleConfig -Name TMP_ADMT_ODB -Description "Dynamic Port Range for ADMT. This rule is intended to ONLY be utilized during deployment and should be removed as soon as possible." -Access Allow -Protocol * -Direction Outbound -Priority 901 -SourceAddressPrefix $OBDSRC_IP -SourcePortRange * -DestinationAddressPrefix $OBDDST_IP -DestinationPortRange $ADMT_port


## sets configurations made
$SELNSG | Set-AzureRmNetworkSecurityGroup



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