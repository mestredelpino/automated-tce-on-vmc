# ---------------------------------------------------------------------------------------------------------------------
# SET THE DATA VALUES
# ---------------------------------------------------------------------------------------------------------------------


# USE THE .TFSTATE FROM PHASE 1 AS DATA SOURCE
data "terraform_remote_state" "phase1" {
  backend = "local"

  config = {
    path = "../phase1/terraform.tfstate"
  }
}

data "terraform_remote_state" "phase2" {
  backend = "local"

  config = {
    path = "../phase2/terraform.tfstate"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SET THE DATA VALUES
# ---------------------------------------------------------------------------------------------------------------------


locals {
  aws_variables = jsondecode(base64decode(data.terraform_remote_state.phase2.outputs.aws_variables))
  sddc_variables = jsondecode(base64decode(data.terraform_remote_state.phase2.outputs.sddc_variables))
  tanzu_variables = jsondecode(base64decode(data.terraform_remote_state.phase2.outputs.tanzu_variables))
  vmc_variables = jsondecode(base64decode(data.terraform_remote_state.phase2.outputs.vmc_variables))
  vpn_variables = jsondecode(base64decode(data.terraform_remote_state.phase2.outputs.vpn_variables))
  tanzuOVA_url = format("%s/%s","../vmware/ovas/",local.tanzu_variables.TF_VAR_tanzuOVA_name)
  focalOVA_url = format("%s/%s","../vmware/ovas/",local.tanzu_variables.TF_VAR_jumpbox_ova)
  focalOVA_name = replace((local.tanzu_variables.TF_VAR_jumpbox_ova), "/(.ova)/","")
  tanzuOVA_name = replace((local.tanzu_variables.TF_VAR_tanzuOVA_name), "/(.ova)/","")
}

# LOAD THE ESXI HOST INFO

data "local_file" "esxi_host_ip" {
  filename = "../phase2/esxi_host.txt"
}

# SET VSPHERE PREDEFINED DATA OBJECTS
data "vsphere_datacenter" "dc" {
  name = "SDDC-Datacenter"
}

data "vsphere_datastore" "datastore" {
  name          = "WorkloadDatastore"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "pool" {
  name          = "Compute-ResourcePool"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# FETCH THE ESXI HOST AND THE NETWORK FROM PREVIOUS STAGES AND ADD THEM AS DATA OBJECTS

data "vsphere_host" "host" {
  name          = data.local_file.esxi_host_ip.content
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# ---------------------------------------------------------------------------------------------------------------------
# SET THE TERRAFORM PROVIDERS AND REQUIRED VERSIONS
# ---------------------------------------------------------------------------------------------------------------------

provider "nsxt" {
  //  alias             = "sddc_a"
  host              = data.terraform_remote_state.phase1.outputs.sddc_a_nsxt_reverse_proxy_url
  vmc_token         = local.vmc_variables.TF_VAR_vmc_refresh_token
  enforcement_point = "vmc-enforcementpoint"

}

provider "vsphere" {
  user           = data.terraform_remote_state.phase1.outputs.sddc_a_vsphere_user
  password       = data.terraform_remote_state.phase1.outputs.sddc_a_vsphere_password
  vsphere_server = replace((data.terraform_remote_state.phase1.outputs.sddc_a_vsphere_url), "/(https://)|(/)/","")
  # If you have a self-signed cert
  allow_unverified_ssl = true
}

terraform {
  required_providers {
    nsxt = {
      source  = "vmware/nsxt"
      version = ">= 3.1.1"
    }
  }
  required_version = ">= 0.14"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE TWO VIRTUAL MACHINES FROM OVA TEMPLATES (AND TURN THE tanzuOVA INTO A TEMPLATE)
# ---------------------------------------------------------------------------------------------------------------------


resource "vsphere_virtual_machine" "focalOVA" {
  name                       = local.focalOVA_name
  resource_pool_id           = data.vsphere_resource_pool.pool.id
  datastore_id               = data.vsphere_datastore.datastore.id
  host_system_id             = data.vsphere_host.host.id
  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout  = 0
  datacenter_id              = data.vsphere_datacenter.dc.id
  network_interface {
    network_id = data.vsphere_network.network.id
  }
  ovf_deploy {
    ovf_network_map = {"VM Network": data.vsphere_network.network.id
    }
    // Url to remote ovf/ova file
    local_ovf_path = local.focalOVA_url
  }
  cdrom {
    client_device = true
  }

}

resource "vsphere_virtual_machine" "tanzuOVA" {
  name                       = local.tanzu_variables.TF_VAR_tanzuOVA_name
  resource_pool_id           = data.vsphere_resource_pool.pool.id
  datastore_id               = data.vsphere_datastore.datastore.id
  host_system_id             = data.vsphere_host.host.id
  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout  = 0
  datacenter_id              = data.vsphere_datacenter.dc.id
  num_cpus = 8
  memory = 10000
  network_interface {
    network_id = data.vsphere_network.network.id
  }

  ovf_deploy {
    ovf_network_map = {"nic0": data.vsphere_network.network.id
    }
    local_ovf_path = local.tanzuOVA_url
  }
  cdrom {
    client_device = true
  }
  provisioner "local-exec" {
    command = <<EOT

Import-Module ../vmware/powerCLI_modules/VMware.VMC.psd1
Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$false
Connect-VMC -RefreshToken  "${local.vmc_variables.TF_VAR_vmc_refresh_token}"
Connect-VMCVIServer -SDDC "${data.terraform_remote_state.phase1.outputs.sddc_a_name}" -Org "${local.vmc_variables.Org}"

# CONVERT THE TANZU VM INTO A TEMPLATE
Stop-VM -VM ${local.tanzu_variables.TF_VAR_tanzuOVA_name} -Confirm:$false || $true
Get-VM -Name ${local.tanzu_variables.TF_VAR_tanzuOVA_name} | Set-VM -ToTemplate -Confirm:$false

  EOT
    interpreter = ["C:/Program Files/PowerShell/7/pwsh.exe", "-Command"]
  }
}
