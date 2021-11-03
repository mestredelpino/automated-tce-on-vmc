
variable "focalOVA_name" {
  default = "focalOVA"
}

variable "jumpbox_ova" {}


variable "tanzuOVA_name" {}

//variable "aviOVA" {
//  type = string
//}


variable "vmc_refresh_token" {
  type        = string
  description = "The VMware Cloud Services API token. This token is scoped within the organization."
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-zA-Z]{64}$", var.vmc_refresh_token))
    error_message = "Only the 64 character alphanumeric VMware Cloud API token is accepted."
  }
}

