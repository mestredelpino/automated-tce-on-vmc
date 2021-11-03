# ---------------------------------------------------------------------------------------------------------------------
# SET THE DATA VALUES
# ---------------------------------------------------------------------------------------------------------------------
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

data "terraform_remote_state" "phase3" {
  backend = "local"

  config = {
    path = "../phase3/terraform.tfstate"
  }
}

data "local_file" "datastore_info_file" {
  filename = "datastoreURL.txt"
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP PROVIDERS AND REQUIRED VERSIONS
# ---------------------------------------------------------------------------------------------------------------------


terraform {
  required_version = ">= 1.0"
}

terraform {
  required_providers {
    vsphere = "~> 2.0.1"
    local = "~> 1.4"
  }
}

provider "vsphere" {
  user                 = data.terraform_remote_state.phase1.outputs.sddc_a_vsphere_user
  password             = data.terraform_remote_state.phase1.outputs.sddc_a_vsphere_password
  vsphere_server       = replace((data.terraform_remote_state.phase1.outputs.sddc_a_vsphere_url), "/(https://)|(/)/","")
  allow_unverified_ssl = true
}

# Generate TKG configuration.

locals {
  mgmt_cluster_control_plane_ip = cidrhost(data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_cidr, 30)
  tkg_services_cluster_control_plane_ip = cidrhost(data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_cidr, 31)
  dev_cluster_control_plane_ip = cidrhost(data.terraform_remote_state.phase1.outputs.sddc_a_vm_segment_cidr, 32)
}

# DEFINE VSPHERE DATA VALUES

data "local_file" "datastore_url" {
  filename = "../phase2/datastore_url.txt"
}

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_network" "network" {
  name          = data.terraform_remote_state.phase2.outputs.default-vm-network-name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_folder" "vm_folder" {
  path          = var.vm_folder
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_resource_pool" "resource_pool" {
  name          = var.resource_pool
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "ubuntu_template" {
  name          = data.terraform_remote_state.phase3.outputs.focalOVA_name
  datacenter_id = data.vsphere_datacenter.dc.id
}


# DEFINE THE FILES THAT WILL BE PROVISIONED TO THE VM

resource "local_file" "vsphere_storage_class" {
  content = templatefile("vsphere-storageclass.yml.tpl", {
    datastore_url = data.local_file.datastore_url.content
  })
  filename        = "vsphere-storageclass.yml"
  file_permission = "0644"
}

resource "local_file" "tkg_configuration_file" {
  content = templatefile("tkg-cluster.yml.tpl", {
    vcenter_server       = replace((data.terraform_remote_state.phase1.outputs.sddc_a_vsphere_url), "/(https://)|(/)/",""),
    vcenter_user         = data.terraform_remote_state.phase1.outputs.sddc_a_vsphere_user,
    vcenter_password     = data.terraform_remote_state.phase1.outputs.sddc_a_vsphere_password,
    datacenter           = var.datacenter,
    datastore            = var.datastore,
    network              = data.terraform_remote_state.phase2.outputs.default-vm-network-name
    resource_pool        = var.resource_pool,
    vm_folder            = var.vm_folder
    control_plane_ip     = local.mgmt_cluster_control_plane_ip
  })
  filename        = "tkg-cluster.yml"
  file_permission = "0644"
}

# Generate additional configuration file.
resource "local_file" "env_file" {
  content = templatefile("env.tpl", {
    control_plane_endpoint_mgmt = local.mgmt_cluster_control_plane_ip
    control_plane_endpoint_tkg_services = local.tkg_services_cluster_control_plane_ip
    control_plane_endpoint_dev = local.dev_cluster_control_plane_ip
    tce_file = var.tce_file
  })
  filename        = "env"
  file_permission = "0644"
}

# Use the jumpbox to access TKG from the outside.
resource "vsphere_virtual_machine" "jumpbox" {
  name             = "jumpbox"
  resource_pool_id = data.vsphere_resource_pool.resource_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  wait_for_guest_net_timeout = -1
  wait_for_guest_ip_timeout  = 2
  num_cpus = 8
  memory   = 6000
  guest_id = "ubuntu64Guest"
  folder   = vsphere_folder.vm_folder.path

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label            = "disk0"
    thin_provisioned = true
    size             = 20
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.ubuntu_template.id

    # Do not include a "customize" section here:
    # this feature is broken with current Ubuntu Cloudimg templates.
  }

  # A CDROM device is required in order to inject configuration properties.
  cdrom {
    client_device = true
  }

  vapp {
    properties = {
      "instance-id" = "jumpbox"
      "hostname"    = "jumpbox"

      # Use our own public SSH key to connect to the VM.
      "public-keys" = file("~/.ssh/id_rsa.pub")
    }
  }

  connection {
    host        = vsphere_virtual_machine.jumpbox.default_ip_address
    timeout     = "30s"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "file" {
    # Copy TKG configuration file.
    source      = "tkg-cluster.yml"
    destination = "/home/ubuntu/tkg-cluster.yml"
  }
  provisioner "file" {
    # Copy additional configuration file.
    source      = "env"
    destination = "/home/ubuntu/.env"
  }

  provisioner "file" {
    # Copy kubectl.
    source      = "../vmware/tanzu/${var.tce_file}"
    destination = "/home/ubuntu/${var.tce_file}"
  }

  provisioner "file" {
    # Copy install scripts.
    source      = "setup-jumpbox-tce.sh"
    destination = "/home/ubuntu/setup-jumpbox.sh"
  }


  provisioner "remote-exec" {
    # Set up jumpbox.
    inline = [
      "echo ${vsphere_virtual_machine.jumpbox.default_ip_address} jumpbox | sudo tee -a /etc/hosts",
      "chmod +x /home/ubuntu/setup-jumpbox.sh",
      "sh /home/ubuntu/setup-jumpbox.sh ",
      "rm /home/ubuntu/setup-jumpbox.sh"
    ]
    on_failure = continue
  }
}



