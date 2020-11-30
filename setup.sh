#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Setup RasPi OS arm64 to run Kubernetes.

DOCKER_VERSION="5:19.03.8~3-0~debian-$(lsb_release -cs)"
DOCKERCLI_VERSION=${DOCKER_VERSION}
CONTAINERD_VERSION="1.2.13-1"
KUBELET_VERSION="1.18.3-00"
KUBEADM_VERSION="1.18.3-00"
KUBECTL_VERSION="1.18.3-00"

# Check this is running as root.
if [[ $EUID -ne 0 ]]; then
   echo "ERROR: This script requires root privileges."
   exit 1
fi

# Remove unnecessary packages to make the OS a bit more 'lite'.
# TODO: Use the RasPi OS Lite version when it is released.
apt-get remove -y --purge x11-common
apt-get autoremove -y

# Disable swap.
dphys-swapfile swapoff && \
  dphys-swapfile uninstall && \
  update-rc.d dphys-swapfile remove
systemctl disable dphys-swapfile

# Enable memory cgroup. 
sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/cmdline.txt

# Set required kernel modules to load.
echo 'br_netfilter' > /etc/modules-load.d/modules.conf

# Let iptables see bridged traffic.
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# Add Docker and Kubernetes apt repos.
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  gnupg2

# Set apt to retry up to 10 times to handle flakiness of Kubernetes repo.
echo "APT::Acquire::Retries \"10\";" > /etc/apt/apt.conf.d/80retries

curl --silent --show-error https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -

cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

curl --silent --show-error --location https://download.docker.com/linux/debian/gpg | apt-key add -

add-apt-repository \
  "deb [arch=arm64] https://download.docker.com/linux/debian \
  $(lsb_release -cs) \
  stable"

apt-get update

# Install Docker.
apt-get install -y \
  containerd.io=${CONTAINERD_VERSION} \
  docker-ce=${DOCKER_VERSION} \
  docker-ce-cli=${DOCKERCLI_VERSION}
apt-mark hold \
  containerd.io \
  docker-ce \
  docker-ce-cli

# Add Docker configuration and reload the service.
mkdir /etc/docker
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
mkdir -p /etc/systemd/system/docker.service.d
systemctl daemon-reload
systemctl restart docker

# Install kubeadm, kubelet and kubectl.
apt-get install -y \
  kubelet=${KUBELET_VERSION} \
  kubeadm=${KUBEADM_VERSION} \
  kubectl=${KUBECTL_VERSION}
apt-mark hold \
  kubelet \
  kubeadm \
  kubectl

# Enable SSH but disabled password login
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
update-rc.d ssh enable

# Change hostname.
NEW_HOSTNAME="raspios-k8s"
OLD_HOSTNAME=$(cat /etc/hostname)
sed -i -e "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
sed -i -e "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hostname
hostname "$NEW_HOSTNAME"
