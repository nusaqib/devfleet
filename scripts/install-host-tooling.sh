#!/usr/bin/env bash
# Install devfleet host tooling on Ubuntu 24.04 (noble): VirtualBox, Packer,
# Vagrant, Ansible. Idempotent — safe to re-run. Requires root (run with sudo).
#
#   sudo scripts/install-host-tooling.sh                      # VirtualBox only
#   sudo DEVFLEET_WITH_LIBVIRT=1 scripts/install-host-tooling.sh  # + libvirt/KVM
#
# After it finishes, log out/in (or `newgrp vboxusers` / `newgrp libvirt`) so the
# group memberships take effect for your user.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run with sudo: sudo $0" >&2
  exit 1
fi

# The unprivileged user to add to vboxusers (the one who invoked sudo).
TARGET_USER="${SUDO_USER:-$USER}"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release wget

install -m 0755 -d /usr/share/keyrings
CODENAME="$(lsb_release -cs)"

# --- HashiCorp repo (Packer + Vagrant) ---------------------------------------
if [[ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]]; then
  wget -qO- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
fi
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${CODENAME} main" \
  > /etc/apt/sources.list.d/hashicorp.list

# --- Oracle VirtualBox repo (7.1) --------------------------------------------
if [[ ! -f /usr/share/keyrings/oracle-virtualbox-2016.gpg ]]; then
  wget -qO- https://www.virtualbox.org/download/oracle_vbox_2016.asc \
    | gpg --dearmor -o /usr/share/keyrings/oracle-virtualbox-2016.gpg
fi
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-virtualbox-2016.gpg] https://download.virtualbox.org/virtualbox/debian ${CODENAME} contrib" \
  > /etc/apt/sources.list.d/virtualbox.list

apt-get update -y

# Kernel headers so VirtualBox can build its modules via dkms.
apt-get install -y "linux-headers-$(uname -r)" dkms
apt-get install -y virtualbox-7.1
apt-get install -y packer vagrant
# Ansible + linter from Ubuntu universe (fine for our use).
apt-get install -y ansible ansible-lint

# Let the user run VirtualBox without root.
usermod -aG vboxusers "$TARGET_USER" || true

# --- libvirt / QEMU provider (optional second provider) ----------------------
# Set DEVFLEET_WITH_LIBVIRT=1 to also set up KVM/libvirt + the vagrant-libvirt
# plugin, so `vagrant up --provider=libvirt` works alongside VirtualBox.
if [[ "${DEVFLEET_WITH_LIBVIRT:-0}" == "1" ]]; then
  echo ">> installing libvirt/QEMU stack"
  apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients \
    virtinst bridge-utils qemu-utils
  # Build deps for the vagrant-libvirt plugin's native extension.
  apt-get install -y libvirt-dev ruby-dev gcc make pkg-config

  systemctl enable --now libvirtd
  usermod -aG libvirt,kvm "$TARGET_USER" || true

  # Ensure a 'default' storage pool exists (vagrant-libvirt uses it). Some hosts
  # ship it; others don't — create it idempotently at the standard location.
  if ! virsh -c qemu:///system pool-info default >/dev/null 2>&1; then
    install -d -m 0711 /var/lib/libvirt/images
    virsh -c qemu:///system pool-define-as default dir --target /var/lib/libvirt/images
    virsh -c qemu:///system pool-start default
    virsh -c qemu:///system pool-autostart default
  fi
  # Ensure the default NAT network is active (guests need it).
  virsh -c qemu:///system net-autostart default 2>/dev/null || true
  virsh -c qemu:///system net-start default 2>/dev/null || true

  # Install the plugin as the unprivileged user (plugins are per-user).
  if ! sudo -u "$TARGET_USER" vagrant plugin list 2>/dev/null | grep -q vagrant-libvirt; then
    sudo -u "$TARGET_USER" vagrant plugin install vagrant-libvirt || \
      echo "WARN: vagrant-libvirt plugin install failed — check libvirt-dev/ruby-dev." >&2
  fi
fi

echo
echo "=== versions ==="
vboxmanage --version || true
packer version || true
vagrant --version || true
ansible --version | head -1 || true
[[ "${DEVFLEET_WITH_LIBVIRT:-0}" == "1" ]] && { virsh --version || true; }

echo
echo "NOTE: if this machine has UEFI Secure Boot ENABLED, the VirtualBox kernel"
echo "modules must be signed/enrolled (MOK) or VMs won't start. Check with:"
echo "    mokutil --sb-state    (if 'SecureBoot enabled', follow the dkms MOK prompt)"
echo
echo "Log out/in (or: newgrp vboxusers; newgrp libvirt) so group membership applies."
