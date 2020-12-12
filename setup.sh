#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

# Setup RasPi OS arm64 to run Kubernetes.

KUBELET_VERSION="1.18.3-00"
KUBEADM_VERSION="1.18.3-00"
KUBECTL_VERSION="1.18.3-00"
CRIO_OS=Debian_Testing
CRIO_VERSION=1.18

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
echo 'br_netfilter' > /etc/modules-load.d/modules.conf

# Let iptables see bridged traffic.
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
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

# Add cri-o apt repo.
cat <<EOF | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
deb [arch=arm64] https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$CRIO_OS/ /
EOF
cat <<EOF | tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION.list
deb [arch=arm64] http://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$CRIO_OS/ /
EOF
curl -L https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$CRIO_VERSION/$CRIO_OS/Release.key | apt-key add -
curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$CRIO_OS/Release.key | apt-key add -

# Update.
until apt-get update; do echo "Retrying..."; done

# Install cri-o.
apt-get install -y --no-install-recommends cri-o
apt-mark hold cri-o

# Configure cri-o.
cat <<EOF | tee /etc/crio/crio.conf.d/01-crio-runc.conf
[crio.runtime.runtimes.runc]
runtime_path = ""
runtime_type = "oci"
runtime_root = "/run/runc"
EOF
systemctl daemon-reload
systemctl enable crio

# Install kubeadm, kubelet and kubectl.
apt-get install -y --no-install-recommends \
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
