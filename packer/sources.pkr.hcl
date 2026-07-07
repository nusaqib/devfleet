// Reusable sources for BOTH providers, parameterized by the same variables.
// Each OS is built by passing a different -var-file; the source bodies are DRY.
// Select a provider at build time with `-only` (see scripts/build.sh):
//   virtualbox → source.virtualbox-iso.vm   |   libvirt → source.qemu.vm

packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/virtualbox"
    }
    qemu = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/qemu"
    }
    ansible = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/ansible"
    }
    vagrant = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}

source "virtualbox-iso" "vm" {
  vm_name          = var.os_name
  output_directory = "output-${var.os_name}" // per-OS so builds don't collide
  guest_os_type    = var.guest_os_type
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum

  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size
  headless  = var.headless

  // Serve the unattended-install config to the booting installer.
  // Anchored to the template dir so it resolves regardless of packer's cwd.
  http_directory = "${path.root}/${var.http_directory}"
  boot_wait      = "5s"
  boot_command   = var.boot_command

  // SSH login the installer sets up; used for provisioning.
  communicator     = "ssh"
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "30m"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"

  guest_additions_mode = "upload"

  vboxmanage = [
    ["modifyvm", "{{ .Name }}", "--nat-localhostreachable1", "on"],
    ["modifyvm", "{{ .Name }}", "--audio-driver", "none"],
  ]
}

// QEMU/KVM source → produces a libvirt-provider Vagrant box. Drives
// qemu-system directly (needs /dev/kvm access, not libvirtd) and reuses the
// SAME unattended-install http dir + boot_command as the VirtualBox source.
source "qemu" "vm" {
  vm_name          = "${var.os_name}.qcow2"
  output_directory = "output-${var.os_name}-qemu" // distinct from the vbox dir
  iso_url          = var.iso_url
  iso_checksum     = var.iso_checksum

  accelerator    = "kvm"
  cpus           = var.cpus
  memory         = var.memory
  disk_size      = "${var.disk_size}M"
  format         = "qcow2"
  disk_interface = "virtio"
  net_device     = "virtio-net"
  headless       = var.headless

  // Same installer config + keystrokes as the VirtualBox build.
  http_directory = "${path.root}/${var.http_directory}"
  boot_wait      = "5s"
  boot_command   = var.boot_command

  communicator     = "ssh"
  ssh_username     = var.ssh_username
  ssh_password     = var.ssh_password
  ssh_timeout      = "30m"
  shutdown_command = "echo '${var.ssh_password}' | sudo -S shutdown -P now"
}
