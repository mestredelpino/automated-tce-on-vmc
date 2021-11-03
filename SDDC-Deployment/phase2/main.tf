# ---------------------------------------------------------------------------------------------------------------------
# SET UP THE .TFSTATE FROM PHASE 1 AS DATA SOURCE
# ---------------------------------------------------------------------------------------------------------------------

data "terraform_remote_state" "phase1" {
  backend = "local"

  config = {
    path = "../phase1/terraform.tfstate"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEFINE THE LOCALS AND DATA VALUES
# ---------------------------------------------------------------------------------------------------------------------

locals {
  endpoint_tag_scope = "Endpoint"
  aws_variables = jsondecode(file("${path.module}/../variables_json/aws_variables.json"))
  sddc_variables = jsondecode(file("${path.module}/../variables_json/sddc_variables.json"))
  tanzu_variables = jsondecode(file("${path.module}/../variables_json/tanzu_variables.json"))
  vmc_variables = jsondecode(file("${path.module}/../variables_json/vmc_variables.json"))
  vpn_variables = jsondecode(file("${path.module}/../variables_json/vpn_variables.json"))
  tags = {
    Terraform = "Managed by Terraform"
  }
}

data "local_file" "cgw_snat_ip_file" {
  filename = "../phase1/cgw_snat_ip.txt"
}

data "nsxt_policy_transport_zone" "sddc_a_tz" {
  provider     = nsxt
  display_name = "vmc-overlay-tz"
}

# ---------------------------------------------------------------------------------------------------------------------
# SET THE TERRAFORM PROVIDERS AND REQUIRED VERSIONS
# ---------------------------------------------------------------------------------------------------------------------


terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = ">= 3.2.2"
    }
  }
  required_version = ">= 0.14"
}

provider "nsxt" {
  host              = data.terraform_remote_state.phase1.outputs.sddc_a_nsxt_reverse_proxy_url
  vmc_token         = local.vmc_variables.TF_VAR_vmc_refresh_token
  enforcement_point = "vmc-enforcementpoint"
}


# ---------------------------------------------------------------------------------------------------------------------
# COMPUTE GATEWAY
# ---------------------------------------------------------------------------------------------------------------------


resource "nsxt_policy_fixed_segment" "sddc_a_default_vm_network" {
  provider            = nsxt
  display_name        = data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_name
  connectivity_path   = "/infra/tier-1s/cgw"
  transport_zone_path = data.nsxt_policy_transport_zone.sddc_a_tz.path

  subnet {
    cidr        = data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_gateway_cidr
    dhcp_ranges = [data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_dhcp_range]
    dhcp_v4_config {
      dns_servers = ["8.8.8.8"]
      lease_time     = 5400
    }
  }
}

# Define the Compute Gateway (CGW) policy groups in SDDC A

resource "nsxt_policy_group" "sddc_a_vm_segment" {
  provider     = nsxt
  domain       = "cgw"
  display_name = data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_name
  description = format(
  data.terraform_remote_state.phase1.outputs.name_specs.name_spec,
  "${data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_name} Compute Group.",
  )
  criteria {
    path_expression {
      member_paths = [nsxt_policy_fixed_segment.sddc_a_default_vm_network.path]
    }
  }
  conjunction { operator = "OR" }
  criteria {
    ipaddress_expression {
      ip_addresses = [data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_cidr]
    }
  }
}

resource "nsxt_policy_group" "workstation_cgw" {
  provider = nsxt
  domain = "cgw"
  display_name = "workstation_cgw"
  criteria {
    ipaddress_expression {
      ip_addresses = [local.vpn_variables.TF_VAR_workstation_public_ip]
    }
  }
}

resource "nsxt_policy_group" "internal_vlan-cgw" {
  provider     = nsxt
  domain       = "cgw"
  display_name = "internal_vlan-cgw"
  criteria {
    ipaddress_expression {
      ip_addresses = [local.vpn_variables.TF_VAR_internal_vlan_ip_range]
    }
  }
}

# Deploy the Compute Gateway (CGW) policies

resource "nsxt_policy_predefined_gateway_policy" "cgw_policy" {
  provider = nsxt
  path     = "/infra/domains/cgw/gateway-policies/default"
  rule {
    action                = "ALLOW"
    destination_groups    = []
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Default VTI Rule"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "default_vti"
    nsx_id                = "default-vti-rule"
    profiles              = []
    scope                 = ["/infra/labels/cgw-vpn"]
    services              = []
    source_groups         = []
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = []
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Tanzu Kubernetes Gid management network's outbound Rule"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "${replace(data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_name, "-", "_")}_outbound"
    profiles              = []
    scope                 = ["/infra/labels/cgw-public"]
    services              = []
    source_groups         = [nsxt_policy_group.sddc_a_vm_segment.path]
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = [nsxt_policy_group.sddc_a_vm_segment.path]
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Allow inbound into the Tanzu Kubernetes Grid management network from the on-premises VLAN"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "${replace(data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_name, "-", "_")}_inbound"
    profiles              = []
    scope                 = ["/infra/labels/cgw-public"]
    services              = ["/infra/services/RDP","/infra/services/SSH","/infra/services/ICMP-ALL","/infra/services/HTTP","/infra/services/HTTPS"]
    source_groups         = [nsxt_policy_group.internal_vlan-cgw.path]
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = []
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "VPC Inbound/Outbound Rule"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "vpc_inbound_outbound"
    notes                 = "Break this up into granular rules."
    profiles              = []
    scope                 = ["/infra/labels/cgw-cross-vpc"]
    services              = []
    source_groups         = []
    sources_excluded      = false
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# MANAGEMENT GATEWAY
# ---------------------------------------------------------------------------------------------------------------------

# DEPLOY THE MANAGEMENT GATEWAY POLICY GROUPS

resource "nsxt_policy_group" "internal_vlan_mgw" {
  provider     = nsxt
  domain       = "mgw"
  display_name = "internal_vlan"
  criteria {
    ipaddress_expression {
      ip_addresses = [local.vpn_variables.TF_VAR_internal_vlan_ip_range]
    }
  }
}

resource "nsxt_policy_group" "workstation" {
  provider     = nsxt
  domain       = "mgw"
  display_name = "workstation"

  criteria {
    ipaddress_expression {
      ip_addresses = [local.vpn_variables.TF_VAR_workstation_public_ip]
    }
  }
}

resource "nsxt_policy_group" "source_nat_ip" {
  provider     = nsxt
  domain       = "mgw"
  display_name = "Source NAT IP"
  criteria {
    ipaddress_expression {
      ip_addresses = [data.local_file.cgw_snat_ip_file.content]
    }
  }
}

# Define the Management Gateway policies.

resource "nsxt_policy_predefined_gateway_policy" "sddc_a_mgw_policy" {
  provider = nsxt
  path     = "/infra/domains/mgw/gateway-policies/default"

  rule {
    action                = "ALLOW"
    destination_groups    = []
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "vCenter Outbound Rule"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "vcenter_outbound"
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = []
    source_groups         = ["/infra/domains/mgw/groups/VCENTER"]
    sources_excluded      = false

  }

  rule {
    action                = "ALLOW"
    destination_groups    = ["/infra/domains/mgw/groups/VCENTER"]
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Allow vCenter access from the workstation from where the SDDC creation is executed"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "vcenter_inbound"
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = ["/infra/services/HTTPS"]
    source_groups         = [nsxt_policy_group.workstation.path]
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = []
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "ESXi Outbound Rule"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "esxi_outbound"
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = []
    source_groups         = ["/infra/domains/mgw/groups/ESXI"]
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = ["/infra/domains/mgw/groups/ESXI"]
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Allow ESXi access from the on-premises VLAN"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "esxi_inbound"
    notes                 = "Break this up into granular rules."
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = ["/infra/services/VMware_Remote_Console","/infra/services/VMware_VMotion","/infra/services/HTTPS","/infra/services/ICMP-ALL"]
    source_groups         = [nsxt_policy_group.internal_vlan_mgw.path]
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = ["/infra/domains/mgw/groups/VCENTER"]
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Allow vCenter access from the VMs in the compute gateway through the Source NAT IP"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "vcenter_inbound_from_cgw"
    notes                 = "Break this up into granular rules."
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = ["/infra/services/HTTPS","/infra/services/ICMP-ALL","/infra/services/SSO"]
    source_groups         = [nsxt_policy_group.source_nat_ip.path]
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = ["/infra/domains/mgw/groups/VCENTER"]
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Allow vCenter access from the Tanzu Kubernetes Grid management network"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "vcenter_inbound_from_cgw"
    notes                 = "Break this up into granular rules."
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = ["/infra/services/HTTPS","/infra/services/ICMP-ALL","/infra/services/SSO"]
    source_groups         = [nsxt_policy_group.sddc_a_vm_segment.path]
    sources_excluded      = false
  }

  rule {
    action                = "ALLOW"
    destination_groups    = ["/infra/domains/mgw/groups/ESXI"]
    destinations_excluded = false
    direction             = "IN_OUT"
    disabled              = false
    display_name          = "Allow ESXi access from the Tanzu Kubernetes Grid management network"
    ip_version            = "IPV4_IPV6"
    logged                = false
    log_label             = "esxi_inbound"
    notes                 = "Break this up into granular rules."
    profiles              = []
    scope                 = ["/infra/labels/mgw"]
    services              = ["/infra/services/VMware_Remote_Console","/infra/services/VMware_VMotion","/infra/services/HTTPS","/infra/services/ICMP-ALL"]
    source_groups         = [nsxt_policy_group.sddc_a_vm_segment.path]
    sources_excluded      = false
  }

}
# ---------------------------------------------------------------------------------------------------------------------
# CREATE VPN
# ---------------------------------------------------------------------------------------------------------------------

resource "null_resource" "retrieveVPNinfo" {
  provisioner "local-exec" {
    command = <<EOT

# IMPORT THE VMC MODULES & THE POWERSHELL FUNCTIONS
$modules = Get-ChildItem ..\ -Recurse | Where-Object {$_.Name -like '*.psd1'}

# IMPORT THE MODULES CONTAINIG THE NECESSARY FUNCTIONS
foreach($module in $modules){
  Import-Module $module
  Write-Host $module.Name "was successfully imported" -fore green
}

# SET VMC ON AWS PARAMETERS
$terraform_state_p1_path = "..\phase1\terraform.tfstate"
#$TFSTATE_Path = "..\phase1\terraform.tfstate"
ImportVarsFromCSV -Path ..\variables\vmc_variables.csv
ImportVarsFromCSV -Path ..\variables\vpn_variables.csv
ImportVarsFromCSV -Path ..\variables\aws_variables.csv
ImportVarsFromCSV -Path ..\variables\sddc_variables.csv
ImportVarsFromCSV -Path ..\variables\tanzu_variables.csv


$terraform_state_p1 = (Get-Content $terraform_state_p1_path -Raw) | ConvertFrom-Json
Get-VMCCredentials-From-TFState -TFState_Path $terraform_state_p1_path -SDDC_name $TF_VAR_sddc_a_name


# CONNECT TO VMC
Connect-Vmc -RefreshToken $TF_VAR_vmc_refresh_token
Connect-NSXTProxy -RefreshToken $TF_VAR_vmc_refresh_token -OrgName $Org -SDDCName $TF_VAR_sddc_a_name

# EXTRACT THE DATASTORE URL BY CONNECTING TO THE VMCVI SERVER
Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false
Connect-VMCVIServer -SDDC $TF_VAR_sddc_a_name -Org $Org
$datastore_url = Get-DatastoreURL -DatastoreName "WorkloadDatastore"
New-Variable -Name "TF_VAR_datastore_url" -Value $datastore_url -scope global -Force
New-Item -Name "TF_VAR_datastore_url" -value $datastore_url -ItemType Variable -Path Env: -Force
$datastore_url | set-content datastore_url.txt -nonewline


# CONNECT TO THE NSXT PROXY AND EXTRACT NSXT AND TERRAFORM PHASE1'S STATE INFO
$nsxt_info = Get-NSXTOverviewInfo
$nsxt_info | ConvertTo-Json > nsxt_info.json
$vpn_public_ip_property = "vpn_internet_ips"
$sddc_infra_subnet = "sddc_infra_subnet"

# IMPORT VARIABLES FROM CSV FILE
ImportVarsFromCSV -Path ..\variables\vpn_variables.csv

# DEFINE THE IP
New-Item -Name "LocalIP" -value $nsxt_info.psobject.properties.Where({$_.Name -eq $vpn_public_ip_property}).value -ItemType Variable -Path Env: -Force
New-Item -Name "SourceIPs_VMCInfraSubnet" -value $nsxt_info.psobject.properties.Where({$_.Name -eq $sddc_infra_subnet}).value -ItemType Variable -Path Env: -Force
New-Item -Name "SourceIPs_DefaultVMNetwork" -value $terraform_state_p1.outputs.sddc_a_vm_segment_cidr.value -ItemType Variable -Path Env: -Force


# ADDITIONALLY EXTRACT THE IP OF THE HOST THE OVA WILL BE DEPLOYED INTO
$your_host = (Get-Datacenter -PipelineVariable dc | Get-Cluster -PipelineVariable cluster | where-object {$_.Name -eq "Cluster-1"} | get-vmhost  | Select @{N = 'Host'; E = {$_.Name}}| Select -last 1).Host
New-Item -Name "TF_VAR_esxi_host" -value $your_host -ItemType Variable -Path Env: -Force
$your_host | set-content esxi_host.txt -nonewline

EOT
    interpreter = ["C:/Program Files/PowerShell/7/pwsh.exe", "-Command"]
    when = create
  }
  depends_on = [nsxt_policy_predefined_gateway_policy.cgw_policy,nsxt_policy_predefined_gateway_policy.sddc_a_mgw_policy]
}

resource "null_resource" "createVPN" {
  provisioner "local-exec" {
    command = <<EOT
# IMPORT THE VMC MODULES & THE POWERSHELL FUNCTIONS
$modules = Get-ChildItem ..\ -Recurse | Where-Object {$_.Name -like '*.psd1'}

# IMPORT THE MODULES CONTAINIG THE NECESSARY FUNCTIONS
foreach($module in $modules){
  Import-Module $module
  Write-Host $module.Name "was successfully imported" -fore green
}

# CONNECT TO VMC AND TO NSXT
Connect-Vmc -RefreshToken "${local.vmc_variables.TF_VAR_vmc_refresh_token}"
Connect-NSXTProxy -RefreshToken "${local.vmc_variables.TF_VAR_vmc_refresh_token}" -OrgName "${local.vmc_variables.Org}" -SDDCName "${data.terraform_remote_state.phase1.outputs.sddc_a_name}"
$nsxt_info = Get-NSXTOverviewInfo
$vpn_public_ip = "vpn_internet_ips"
$sddc_infra_subnet = "sddc_infra_subnet"

# IMPORT DATA FROM TERRAFORM'S PHASE 1 REMOTE STATE
$terraform_state_p1_path = "..\phase1\terraform.tfstate"
$terraform_state_p1 = (Get-Content $terraform_state_p1_path -Raw) | ConvertFrom-Json


# EXTRACT VPN PARAMETERS FROM NSXT_INFO AND FROM TERRAFORM'S PHASE 1 REMOTE STATE
$LocalIP = $nsxt_info.psobject.properties.Where({$_.Name -eq $vpn_public_ip}).value
$SourceIPs_VMCInfraSubnet = $nsxt_info.infra_subnets
$SourceIPs_DefaultVMNetwork = $terraform_state_p1.outputs.sddc_a_vm_segment_cidr.value

# CREATE VPN (AND PREVIOUSLY DELETE IT IF IT EXISTS)
$VPNexists = Get-NSXTPolicyBasedVPN
if($VPNexists.Name -eq "${local.vpn_variables.Name}"){
  Remove-NSXTPolicyBasedVPN -Name "${local.vpn_variables.Name}"
  Write-Host "Waiting 1 minute while VPN gets deleted"
  Start-Sleep -s 60
  New-NSXTPolicyBasedVPN -Name "${local.vpn_variables.Name}" `
    -LocalIP $LocalIP `
    -RemotePublicIP "${local.vpn_variables.RemotePublicIP}" `
    -RemotePrivateIP "${local.vpn_variables.RemotePrivateIP}" `
    -SequenceNumber "${local.vpn_variables.SequenceNumber}" `
    -SourceIPs @($SourceIPs_VMCInfraSubnet, $SourceIPs_DefaultVMNetwork) `
    -DestinationIPs @("${local.vpn_variables.DestinationIPs}") `
    -TunnelEncryption "${local.vpn_variables.TunnelEncryption}" `
    -TunnelDigestEncryption "${local.vpn_variables.TunnelDigestEncryption}" `
    -IKEEncryption "${local.vpn_variables.IKEEncryption}" `
    -IKEDigestEncryption "${local.vpn_variables.IKEDigestEncryption}" `
    -DHGroup "${local.vpn_variables.DHGroup}" `
    -IKEVersion "${local.vpn_variables.IKEVersion}" `
    -PresharedPassword "${local.vpn_variables.PresharedPassword}" `
    -Troubleshoot
}else{
  New-NSXTPolicyBasedVPN -Name "${local.vpn_variables.Name}" `
    -LocalIP $LocalIP `
    -RemotePublicIP "${local.vpn_variables.RemotePublicIP}" `
    -RemotePrivateIP "${local.vpn_variables.RemotePrivateIP}" `
    -SequenceNumber "${local.vpn_variables.SequenceNumber}" `
    -SourceIPs @($SourceIPs_VMCInfraSubnet, $SourceIPs_DefaultVMNetwork) `
    -DestinationIPs @("${local.vpn_variables.DestinationIPs}") `
    -TunnelEncryption "${local.vpn_variables.TunnelEncryption}" `
    -TunnelDigestEncryption "${local.vpn_variables.TunnelDigestEncryption}" `
    -IKEEncryption "${local.vpn_variables.IKEEncryption}" `
    -IKEDigestEncryption "${local.vpn_variables.IKEDigestEncryption}" `
    -DHGroup "${local.vpn_variables.DHGroup}" `
    -IKEVersion "${local.vpn_variables.IKEVersion}" `
    -PresharedPassword "${local.vpn_variables.PresharedPassword}" `
    -Troubleshoot
}

Write-Host "Sleeping for 1 minute"
start-sleep -s 60

route ADD $SourceIPs_VMCInfraSubnet MASK 255.255.0.0 "${local.vpn_variables.TF_VAR_your_gateway_ip}" -p
route ADD $SourceIPs_DefaultVMNetwork MASK 255.255.255.0 "${local.vpn_variables.TF_VAR_your_gateway_ip}" -p

EOT
    interpreter = ["C:/Program Files/PowerShell/7/pwsh.exe", "-Command"]
    when = create
  }
  depends_on = [null_resource.retrieveVPNinfo]
}

resource "null_resource" "destroyVPN" {
  provisioner "local-exec" {
    command = <<EOT
# IMPORT THE VMC MODULES & THE POWERSHELL FUNCTIONS
$modules = Get-ChildItem ..\ -Recurse | Where-Object {$_.Name -like '*.psd1'}

# IMPORT THE MODULES CONTAINIG THE NECESSARY FUNCTIONS
foreach($module in $modules){
  Import-Module $module
  Write-Host $module.Name "was successfully imported" -fore green
}

# IMPORT VARIABLES FROM CSV FILE
ImportVarsFromCSV -Path ..\variables\vmc_variables.csv
ImportVarsFromCSV -Path ..\variables\vpn_variables.csv

# CONNECT TO VMC AND TO NSXT
Connect-Vmc -RefreshToken $TF_VAR_vmc_refresh_token
Connect-NSXTProxy -RefreshToken $TF_VAR_vmc_refresh_token -OrgName $Org -SDDCName $TF_VAR_sddc_a_name
$nsxt_info = Get-NSXTOverviewInfo
$vpn_public_ip_property = "vpn_internet_ips"
$sddc_infra_subnet = "sddc_infra_subnet"

$terraform_state_p1_path = "..\phase1\terraform.tfstate"
$terraform_state_p1 = (Get-Content $terraform_state_p1_path -Raw) | ConvertFrom-Json

$LocalIP = $nsxt_info.psobject.properties.Where({$_.Name -eq $vpn_public_ip_property}).value
$SourceIPs_VMCInfraSubnet = $nsxt_info.infra_subnets #$nsxt_info.psobject.properties.Where({$_.Name -eq $sddc_infra_subnet}).value
$SourceIPs_DefaultVMNetwork = $terraform_state_p1.outputs.sddc_a_vm_segment_cidr.value #$nsxt_info. #$terraform_state_p1.outputs.sddc_a_vm_segment_cidr.value


# DELETE THE POLICY BASED VPN
$VPNexists = Get-NSXTPolicyBasedVPN
if($VPNexists.Name -eq $Name){
  Remove-NSXTPolicyBasedVPN -Name $Name
Write-Host "VPN succesfully deleted" -fore green
}

EOT
    interpreter = ["C:/Program Files/PowerShell/7/pwsh.exe", "-Command"]
    when = destroy
  }
}
