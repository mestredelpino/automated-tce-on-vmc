## AWS Variables
1. AWS_ACCESS_KEY_ID: Specifies an AWS access key associated with an IAM user or role.
2. AWS_SECRET_ACCESS_KEY: Specifies the secret key associated with the access key. This is essentially the "password" for the access key.
3. AWS_SESSION_TOKEN:Specifies the session token value that is required if you are using temporary security credentials that you retrieved directly from AWS STS operations.
4. TF_VAR_aws_account_number: Your AWS billing account number.
5. TF_VAR_sddc_a_connected_vpc_cidr: The CIDR of the AWS VPC that will be created.

## SDDC Variables
1. TF_VAR_sddc_a_mgmt_cidr: The CIDR of the SDDC's Infrastructure Network (where the ESXi hosts and vCenter will be deployed).
2. TF_VAR_sddc_a_vm_segment_cidr: The CIDR of the TCE-Management network, (where the TCE cluster will be deployed).

## Tanzu Variables
TF_VAR_ubuntuOVA_name: The name of the OVA used as image for the TCE clusters (for example: "photon-3-kube-v1.21.2+vmware.1-tkg.2-12816990095845873721.ova").
TF_VAR_jumpbox_ova: The name of the focal server cloud OVA which will serve as image for the jumpbox ("focal-server-cloudimg-amd64.ova" if using the ova provided in the manual).
TF_VAR_tce_file, The name of the file containing the TCE CLI (for example: "tce-linux-amd64-v0.9.1.tar.gz").
TF_VAR_vm_folder: The vSphere folder in which the jumpbox and TCE clusters will be deployed in.

## VMC Variables
TF_VAR_vmc_refresh_token: The VMC access token that you recently created (and gave NSX-T admin rights).
Org: Your AWS organization name.
TF_VAR_sddc_a_name: The name of the SDDC that will get deployed.
TF_VAR_vmc_org_id: Your VMC organization ID.
TF_VAR_sddc_a_region: The AWS region in which the VPC will be created.

## VPN Variables
Name: The name of the IPSec VPN tunnel you will create.
RemotePublicIP: The Public IP of your VPN concentrator.
RemotePrivateIP: Your local network's private IP address.
SequenceNumber: An integer representing the IPSEC sequence number (for example: 0).
DestinationIPs: Your internal VLAN's network CIDR.
TunnelEncryption: Tunnel encryption algorithm, (for example: "AES_256").
TunnelDigestEncryption: The VPN tunnel's digest encryption algorithm (for example: "SHA1").
IKEEncryption: Internet Key Exchange encryption algorithm (for example: "AES_256").
IKEDigestEncryption: The Internet Key Exchange digest encryption algorithm (for example: "SHA1").
DHGroup: The Diffie-Hellman algorithm (for example: "GROUP14").
IKEVersion: The Internet Key Exchange protocol (for example: "IKE_V2").
PresharedPassword: The VPN's pre-shared key.
TF_VAR_internal_vlan_ip_range: Your internal VLAN's IP range.
TF_VAR_workstation_public_ip: Your workstation's IP address.
TF_VAR_your_gateway_ip: Your gateway's IP address.
