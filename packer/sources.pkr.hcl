// A single reusable virtualbox-iso source, parameterized by variables.
// Each OS is built by passing a different -var-file; the source body is DRY.

packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.1.1"
      source  = "github.com/hashicorp/virtualbox"
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
  output_directory = "output-${var.os_name}"  // per-OS so builds don't collide
  guest_os_type    = var.guest_os_type
  iso_url       = var.iso_url
  iso_checksum  = var.iso_checksum

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
