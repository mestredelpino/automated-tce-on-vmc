#!/bin/sh
. /home/ubuntu/.env

# Uncompress TKG archive and install CLI.
if [ -f ~/$tce_file ]; then
  echo " The tce file is $tce_file" && \
  cd ~/ && \
  filename_without_extension=$(basename "$tce_file" .tar.gz) && \

  mkdir /home/ubuntu/tanzu && mv /home/ubuntu/$tce_file /home/ubuntu/tanzu && \
    cd /home/ubuntu/tanzu && \
    tar xzvf $tce_file &&  \
    cd $filename_without_extension &&  \
    ./install.sh
fi

# Generate a default TKG configuration.
#if ! [ -f /home/ubuntu/.tanzu/tkg/cluster-config.yaml ]; then
#  tanzu init > /dev/null 2>&1
#  tanzu management-cluster create > /dev/null 2>&1
#  mkdir -p ~/.config/tanzu/tkg/clusterconfigs
#  cat <<EOF >> ~/.config/tanzu/tkg/clusterconfigs/mgmt-cluster-config.yaml
#CLUSTER_NAME: mgmt
##CLUSTER_PLAN: dev
#VSPHERE_CONTROL_PLANE_ENDPOINT: "$CONTROL_PLANE_ENDPOINT"
#EOF
#fi

# Generate a SSH keypair.
if ! [ -f /home/ubuntu/.ssh/id_rsa ]; then echo "true"
  ssh-keygen -t rsa -f /home/ubuntu/.ssh/id_rsa -q -P ''
fi

## Install K8s CLI.
#if ! [ -f /usr/local/bin/kubectl ]; then
#  K8S_VERSION= v1.21.2 # v1.20.5
#  curl -LO https://storage.googleapis.com/kubernetes-release/release/$K8S_VERSION/bin/linux/amd64/kubectl && \
#    chmod +x ./kubectl && \
#    sudo install ./kubectl /usr/local/bin/kubectl
#    echo 'source <(kubectl completion bash)' >> ~/.bashrc
#fi

# INSTALL TANZU'S KUBECTL

#if [ -f ~/$kubectl_file ]; then
#  name=$(basename "$kubectl_file" .gz)
#  gunzip ~/$kubectl_file && sudo install ~/$name /usr/local/bin/kubectl
#fi

curl -LO https://dl.k8s.io/release/v1.20.1/bin/linux/amd64/kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Configure TKG.
if [ -f /home/ubuntu/tkg-cluster.yml ]; then
  tanzu init > /dev/null 2>&1
  tanzu management-cluster create > /dev/null 2>&1
  mkdir -p ~/.config/tanzu/tkg/clusterconfigs
  cat /home/ubuntu/tkg-cluster.yml >> ~/.config/tanzu/tkg/config.yaml
  SSH_PUBLIC_KEY=`cat /home/ubuntu/.ssh/id_rsa.pub`
  cat <<EOF >> ~/.config/tanzu/tkg/config.yaml
VSPHERE_SSH_AUTHORIZED_KEY: "$SSH_PUBLIC_KEY"
EOF
#  cp ~/.config/tanzu/tkg/config.yaml ~/.config/tanzu/tkg/clusterconfigs/mgmt_cluster_config.yaml
#  cp ~/.config/tanzu/tkg/config.yaml ~/.config/tanzu/tkg/clusterconfigs/tkg_services_cluster_config.yaml
  cat <<EOF >> ~/.config/tanzu/tkg/clusterconfigs/mgmt_cluster_config.yaml
CLUSTER_NAME: mgmt
CLUSTER_PLAN: dev
VSPHERE_CONTROL_PLANE_ENDPOINT: "$CONTROL_PLANE_ENDPOINT_MGMT"
EOF
    cat <<EOF >> ~/tkg_services_cluster_config.yaml
CLUSTER_NAME: tkg-services
CLUSTER_PLAN: dev
VSPHERE_CONTROL_PLANE_ENDPOINT: "$CONTROL_PLANE_ENDPOINT_TKG_SERVICES"
EOF
  mv ~/tkg_services_cluster_config.yaml ~/.config/tanzu/tkg/clusterconfigs/tkg_services_cluster_config.yaml
  /bin/rm -f /home/ubuntu/tkg-cluster.yml
fi

# Install yq.
sudo snap install yq

# Configure VIm.
if ! [ -f /home/ubuntu/.vimrc ]; then
  cat <<EOF >> /home/ubuntu/.vimrc
set ts=2
set sw=2
set ai
set et
EOF
fi

# Install Docker.
sudo apt-get update && \
sudo apt-get -y install docker.io && \
sudo ln -sf /usr/bin/docker.io /usr/local/bin/docker && \
sudo usermod -aG docker ubuntu

# Install kind to be able to clean up the environment in case of deployment failure
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind


# Install jq
sudo apt update
sudo apt install -y jq

# Install carvel tools
wget -O- https://carvel.dev/install.sh > install.sh
sudo bash install.sh
