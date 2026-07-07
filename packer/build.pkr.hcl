// The build block. Both provider sources share the SAME provisioning: install
// Ansible prereqs, run the shared `base` playbook, clean up. Provider-specific
// steps (Guest Additions vs qemu-guest-agent) are scoped with `only`.
// This is the crux of reproducibility — build-time and run-time share the role.

build {
  name = "devfleet"
  sources = [
    "source.virtualbox-iso.vm",
    "source.qemu.vm",
  ]

  // 1. Ensure Python/Ansible prerequisites exist in the guest.
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/ansible-prereqs.sh"
  }

  // 2. Provision with the shared Ansible role (same one Vagrant uses at run time).
  //    --scp-extra-args '-O' + scp transfer: Packer's ansible proxy doesn't
  //    speak the SFTP protocol that modern (OpenSSH 9+) scp uses by default, so
  //    file-copying modules (copy/template) fail without forcing legacy SCP.
  provisioner "ansible" {
    playbook_file = "${path.root}/../ansible/playbooks/base.yml"
    user          = var.ssh_username
    extra_arguments = [
      "--extra-vars", "devfleet_context=image",
      "--scp-extra-args=-O", // one token: a bare "-O" would be parsed as a flag
    ]
    ansible_env_vars = [
      "ANSIBLE_CONFIG=${path.root}/../ansible/ansible.cfg",
      "ANSIBLE_SSH_TRANSFER_METHOD=scp",
    ]
  }

  // 3. Provider-portable networking (shell = reliably lands in the image).
  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/network-portable.sh"
  }

  // 3a. VirtualBox only: install Guest Additions (native vboxsf / clipboard).
  provisioner "shell" {
    only            = ["virtualbox-iso.vm"]
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/install-guest-additions.sh"
  }

  // 3b. QEMU/libvirt only: install the guest agent (host<->guest integration).
  provisioner "shell" {
    only            = ["qemu.vm"]
    execute_command = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script          = "${path.root}/scripts/install-qemu-guest-agent.sh"
  }

  // 4. Zero out logs/history/free space so the box is small and clean.
  provisioner "shell" {
    execute_command   = "echo '${var.ssh_password}' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    script            = "${path.root}/scripts/cleanup.sh"
    expect_disconnect = true
  }

  // 5. Emit a Vagrant box. {{ .Provider }} is "virtualbox" or "libvirt"
  //    depending on which source produced it.
  post-processor "vagrant" {
    output = "${path.root}/../builds/${var.os_name}-{{ .Provider }}.box"
  }
}
