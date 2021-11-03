output "default-vm-network-group" {
  value = nsxt_policy_group.sddc_a_vm_segment.path
}

output "default-vm-network-name" {
  value = nsxt_policy_fixed_segment.sddc_a_default_vm_network.display_name
}

output "aws_variables" {
  value = base64encode(jsonencode(local.aws_variables))
  sensitive = true
}

output "sddc_variables" {
  value = base64encode(jsonencode(local.sddc_variables))
  sensitive = true
}

output "tanzu_variables" {
  value = base64encode(jsonencode(local.tanzu_variables))
  sensitive = true
}

output "vmc_variables" {
  value = base64encode(jsonencode(local.vmc_variables))
  sensitive = true
}

output "vpn_variables" {
  value = base64encode(jsonencode(local.vpn_variables))
  sensitive = true
}

output "cgw_snat_ip" {
  value = data.local_file.cgw_snat_ip_file.content
}
