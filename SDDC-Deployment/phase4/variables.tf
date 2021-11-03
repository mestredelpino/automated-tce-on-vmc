variable "datacenter" {
  type    = string
  default = "SDDC-Datacenter"
}

variable "cluster" {
  type    = string
  default = "Cluster-1"
}

variable "datastore" {
  type    = string
  default = "WorkloadDatastore"
}

variable "vm_folder" {
  type    = string
}

variable "resource_pool" {
  type    = string
  default = "Compute-ResourcePool"
}

variable "tce_file" {
  type = string
}


