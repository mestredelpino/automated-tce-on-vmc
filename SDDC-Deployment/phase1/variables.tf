 variable "vmc_org_id" {
  type        = string
  description = "The VMware Cloud long organization identifier (eg: 01234567-89ab-cdef-0123-456789abcdef)."

  validation {
    condition     = can(regex("^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$", var.vmc_org_id))
    error_message = "Only the long format organization identifier is accepted."
  }
}

variable "vmc_refresh_token" {
  type        = string
  description = "The VMware Cloud Services API token. This token is scoped within the organization."
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-zA-Z]{64}$", var.vmc_refresh_token))
    error_message = "Only the 64 character alphanumeric VMware Cloud API token is accepted."
  }
}

variable "sddc_a_region" {
  type        = string
  description = "The AWS Region in which the first software-defined data center (SDDC) will be created (eg: eu-west-1)."

  validation {
    condition     = can(regex("^ap-northeast-[12]|ap-south-1|ap-southeast-[12]|(?:ca|eu)-central-1|eu-north-1|eu-west-[123]|sa-east-1|us-east-[12]|us-west-[12]$", var.sddc_a_region))
    error_message = "Unsupported VMware Cloud on AWS Region (https://docs.vmware.com/en/VMware-Cloud-on-AWS/services/com.vmware.vmc-aws-operations/GUID-9708C514-30FE-4D75-A3E4-E358166EEB1F.html)."
  }
}

variable "sddc_a_name" {
  type        = string
  description = "The name of the SDDC."
}

variable "sddc_a_mgmt_cidr" {
  type        = string
  description = "The IPv4 CIDR block for the first SDDC's management network. This private subnet range (RFC 1918) is used for the vCenter Server, NSX Manager, and ESXi hosts and only a prefix of '/16', '/20', or '/23' are supported. Choose a range that will not conflict with other networks you will connect to or use in this SDDC. A '/23' supports up to 27 hosts, '/20' supports up to 251 hosts, and '/16' supports up to 4091 hosts. Reserved CIDR blocks: '10.0.0.0/15' and '172.31.0.0/16'."
  default     = "10.2.0.0/16"

  validation {
    condition     = can(regex("^(?:192\\.168\\.(?:1?\\d?\\d|2[0-4]\\d|25[0-4])|172\\.(?:1[6-9]|2\\d|30)\\.(?:1?\\d?\\d|2[0-4]\\d|25[0-4])|10\\.(?:[2-9]|\\d{2}|1\\d{2}|2[0-4]\\d|25[0-4])\\.(?:1?\\d?\\d|2[0-4]\\d|25[0-4]))\\.0\\/(?:16|20|23)$", var.sddc_a_mgmt_cidr))
    error_message = "Only 16-bit, 20-bit, and 23-bit RFC 1918 CIDR blocks are supported. Reserved CIDR blocks: '10.0.0.0/15' and '172.31.0.0/16'."
  }
}

variable "sddc_a_vm_segment_cidr" {
  type        = string
  description = "The 24-bit IPv4 CIDR block for the first SDDC's VM network segment."
  default     = "10.22.2.0/24"

  validation {
    condition     = can(regex("^(?:192\\.168\\.(?:1?\\d?\\d|2[0-4]\\d|25[0-4])|172\\.(?:1[6-9]|2\\d|30)\\.(?:1?\\d?\\d|2[0-4]\\d|25[0-4])|10\\.(?:[2-9]|\\d{2}|1\\d{2}|2[0-4]\\d|25[0-4])\\.(?:1?\\d?\\d|2[0-4]\\d|25[0-4]))\\.0\\/24$", var.sddc_a_vm_segment_cidr))
    error_message = "Only 24-bit RFC 1918 CIDR blocks are supported."
  }
}


variable "aws_account_number" {
  type        = string
  description = "The AWS account number that will be linked to the VMware Cloud on AWS account via cross-account elastic network interfaces (x-ENIs)."

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_number))
    error_message = "Only the 12 digit AWS account number is accepted."
  }
}
//
variable "sddc_a_connected_vpc_cidr" {
  type        = string
  description = "An IPv4 CIDR block that will be used to create a new VPC subnet to which the VMware Cloud on AWS cross-account elastic network interfaces (x-ENIs) will be connected. Choose a range that will not conflict with other networks you will connect to or use in this SDDC."
  default     = "172.30.0.0/16"

  validation {
    condition     = can(regex("^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9]?[0-9])\\/1[6-9]$", var.sddc_a_connected_vpc_cidr))
    error_message = "Only IPv4 CIDR blocks between 19-bit and 16-bit are supported."
  }
}


variable "sso_domain" {
  type        = string
  description = "The SSO domain name to use for vSphere users."
  default     = "vmc.local"
}

variable "region_azs" {
  type = map(object({
    az1 = string
    az2 = string
  }))
  description = "The two AWS Availability Zones (AZs) to use for each region. The az1 value needs to be an AZ with VMC instance capacity. The az2 value can be any other AZ. Two AZs are required for AWS Managed AD, which is used in the Native Integrations lab."
  default = {
    ap-northeast-1 = {
      az1 = "apne1-az4"
      az2 = "apne1-az2"
    }
    ap-northeast-2 = {
      az1 = "apne2-az3"
      az2 = "apne2-az1"
    }
    ap-south-1 = {
      az1 = "aps1-az2"
      az2 = "aps1-az3"
    }
    ap-southeast-1 = {
      az1 = "apse1-az1"
      az2 = "apse1-az3"
    }
    ap-southeast-2 = {
      az1 = "apse2-az2"
      az2 = "apse2-az1"
    }
    ca-central-1 = {
      az1 = "cac1-az2"
      az2 = "cac1-az1"
    }
    eu-central-1 = {
      az1 = "euc1-az3"
      az2 = "euc1-az1"
    }
    ca-north-1 = {
      az1 = "eun1-az2"
      az2 = "eun1-az1"
    }
    eu-west-1 = {
      az1 = "euw1-az1"
      az2 = "euw1-az3"
    }
    eu-west-2 = {
      az1 = "euw2-az2"
      az2 = "euw2-az3"
    }
    eu-west-3 = {
      az1 = "euw3-az3"
      az2 = "euw3-az1"
    }
    sa-east-1 = {
      az1 = "sae1-az3"
      az2 = "sae1-az1"
    }
    us-east-1 = {
      az1 = "use1-az4"
      az2 = "use1-az2"
    }
    us-east-2 = {
      az1 = "use2-az3"
      az2 = "use2-az1"
    }
    us-west-1 = {
      az1 = "usw1-az3"
      az2 = "usw1-az1"
    }
    us-west-2 = {
      az1 = "usw2-az1"
      az2 = "usw2-az2"
    }
  }
}

 variable "sddc-cgw-network1" {
   default = "10.22.1.0/24"
 }
