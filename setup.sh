#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Setup RasPi OS to run Kubernetes.

KUBELET_VERSION="1.18.3-00"
KUBEADM_VERSION="1.18.3-00"
KUBECTL_VERSION="1.18.3-00"

CONTAINERD_VERSION="1.4.3-1"

# If ARCH is not set default to arm64.
if [ -z "$ARCH" ]; then
  ARCH="arm64"
fi

# Other assets used by this script are assumed to be located at /raspios-k8s.
ASSET_DIR="/raspios-k8s"

# Check this is running as root.
if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script requires root privileges."
  exit 1
fi

# Disable swap.
dphys-swapfile swapoff && \
  dphys-swapfile uninstall && \
  update-rc.d dphys-swapfile remove
systemctl disable dphys-swapfile

# Enable memory cgroup. 
sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/cmdline.txt

# Set required kernel modules to load.
cat <<EOF | tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

# Let iptables see bridged traffic.
cat <<EOF | tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system

# Install utilities.
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  gnupg2

# Set apt to retry up to 10 times to handle flakiness of Kubernetes repo.
echo "APT::Acquire::Retries \"10\";" > /etc/apt/apt.conf.d/80retries

# Add Kubernetes apt repo.
curl --silent --show-error https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

# Add Docker apt repo.
curl --silent --show-error --location https://download.docker.com/linux/debian/gpg | apt-key add -
cat <<EOF | tee /etc/apt/sources.list.d/docker.list
deb [arch=$ARCH] https://download.docker.com/linux/debian buster stable
EOF

# Update and upgrade.
until apt-get update; do echo "Retrying..."; done
apt-get upgrade -y

# Install containerd.
apt-get install -y --no-install-recommends containerd.io=${CONTAINERD_VERSION}
apt-mark hold containerd.io

# Add containerd configuration and reload the service.
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml
cat <<EOF | tee -a /etc/containerd/config.toml

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
EOF

# Install kubeadm, kubelet and kubectl.
apt-get install -y --no-install-recommends \
  kubelet=${KUBELET_VERSION} \
  kubeadm=${KUBEADM_VERSION} \
  kubectl=${KUBECTL_VERSION}
apt-mark hold \
  kubelet \
  kubeadm \
  kubectl

# Copy in the example kubeadm config file.
cp /raspios-k8s/kubeadm.yaml /home/pi/kubeadm.yaml

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

# Copy boot script and set it to run using rc.local.
cp "${ASSET_DIR}/boot.sh" /usr/local/bin/raspios-k8s-boot.sh
chmod +x /usr/local/bin/raspios-k8s-boot.sh
cat <<EOF | tee /etc/rc.local
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.

/usr/local/bin/raspios-k8s-boot.sh &
exit 0
EOF
