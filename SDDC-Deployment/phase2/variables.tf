//variable "vmc_refresh_token" {
//  type        = string
//  description = "The VMware Cloud Services API token. This token is scoped within the organization."
//  sensitive   = true
//
//  validation {
//    condition     = can(regex("^[0-9a-zA-Z]{64}$", var.vmc_refresh_token))
//    error_message = "Only the 64 character alphanumeric VMware Cloud API token is accepted."
//  }
//}
//
//variable "internal_vlan_ip_range" {
//  description = "The IP range of your internal VLAN"
//  type = string
//}
//
//variable "workstation_public_ip" {
//  description = "The public IP of your current workstation"
//  type = string
//  validation {
//    condition = can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$",var.workstation_public_ip))
//    error_message = "Please provide a valid IP address."
//  }
//}
//
//variable "avi_mgmt_cidr" {
//  type = string
//}
//
//variable "avi_backend_cidr" {
//  type = string
//}
//
//variable "avi_vip_cidr" {
//  type = string
//}

