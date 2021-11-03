$sshKey_path = "C:\Users\Administrator\.ssh\"
$sshKey_name = "id_rsa"
$sshKey_full_path = $sshKey_path + $sshKey_name
$known_hosts_file = "known_hosts"
$ssh_known_hosts = $sshKey_path + $known_hosts_file

$terraform_state_p4_path = "..\phase4\terraform.tfstate"
$terraform_state_p4 = (Get-Content $terraform_state_p4_path -Raw) | ConvertFrom-Json
$jumphost_ip_address = $terraform_state_p4.outputs[0].jumpbox_ip_address.value

Clear-Content $ssh_known_hosts
ssh -i $sshKey_full_path ubuntu@$jumphost_ip_address
#
#rm -rf ~/.tanzu/tkg/bom
#export TKG_BOM_CUSTOM_IMAGE_TAG="v1.3.1-patch1"
#tanzu management-cluster create -y


#Get-Command -Module SSH-Sessions

#New-SshSession -ComputerName  -Username ubuntu -Password puppet -

#New-SSHSession -ComputerName ubuntu@$jumphost_ip_address -KeyFile $sshKey_full_path



