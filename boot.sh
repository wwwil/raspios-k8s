#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# Useful for debug.
#set -o xtrace

# raspios-k8s boot script to be run by rc.local.

# Copy SSH public key from /boot/.
if [ -f /boot/id_rsa.pub ]; then
  # Create SSH directory if not present.
  if [ ! -d /home/pi/.ssh ]; then
    mkdir -p /home/pi/.ssh
    chmod 700 /home/pi/.ssh
    chown pi:pi /home/pi/.ssh
  fi
  # Create authorized keys file if not present.
  if [ ! -f /home/pi/.ssh/authorized_keys ]; then
    touch /home/pi/.ssh/authorized_keys
    chmod 700 /home/pi/.ssh
    chown pi:pi /home/pi/.ssh
  fi
  cat /boot/id_rsa.pub >> /home/pi/.ssh/authorized_keys
  rm /boot/id_rsa.pub
fi

# Change hostname.
NEW_HOSTNAME=$(cat /boot/hostname)
OLD_HOSTNAME=$(cat /etc/hostname)
sed -i -e "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts
sed -i -e "s/$OLD_HOSTNAME/$NEW_HOSTNAME/g" /etc/hostname
hostname "$NEW_HOSTNAME"
rm /boot/hostname
systemctl restart avahi-daemon.service

# TODO: Set static IP from config file in /boot.
# TODO: Run kubeadm using config in /boot.

# Print information.
echo "Hostname: $(hostname)"
echo "IP addresses: $(hostname -I)"

exit 0
