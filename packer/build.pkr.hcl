// The build block. Reuses ONE source and applies the SAME provisioning to every
// OS: install Ansible prereqs, run the shared `base` playbook, then clean up.
// This is the crux of reproducibility — build-time and run-time share the role.

build {
  name    = "devfleet"
  sources = ["source.virtualbox-iso.vm"]

  // 1. Ensure Python/Ansible prerequisites exist in the guest.
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/ansible-prereqs.sh"
  }

  // 2. Provision with the shared Ansible role (same one Vagrant uses at run time).
  provisioner "ansible" {
    playbook_file = "${path.root}/../ansible/playbooks/base.yml"
    user          = var.ssh_username
    extra_arguments = [
      "--extra-vars", "devfleet_context=image",
    ]
    ansible_env_vars = ["ANSIBLE_CONFIG=${path.root}/../ansible/ansible.cfg"]
  }

  // 3. Install VirtualBox Guest Additions (native shared folders / clipboard).
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/install-guest-additions.sh"
  }

  // 4. Zero out logs/history/free space so the box is small and clean.
  provisioner "shell" {
    execute_command   = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script            = "${path.root}/scripts/cleanup.sh"
    expect_disconnect = true
  }

  // 5. Emit a Vagrant box consumable by the vagrant/ layer.
  post-processor "vagrant" {
    output = "${path.root}/../builds/${var.os_name}-{{ .Provider }}.box"
  }
}
