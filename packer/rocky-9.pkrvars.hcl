// Rocky Linux 9 (boot ISO) — uses Anaconda kickstart.
// Pin a concrete point release for reproducible checksums (avoid "latest").

os_name       = "rocky-9"
guest_os_type = "RedHat_64"
iso_url       = "https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.8-x86_64-boot.iso"
iso_checksum  = "sha256:d6eeefdc8437c593d41a3150fcca4a734c55642ed472eecdda99720bb1370881"

http_directory = "http/rocky"

// VirtualBox boots this ISO via isolinux (BIOS), whose menu says "Press Tab
// for full configuration options". Tab reveals the append line; add the
// kickstart URL + text mode, then Enter. (NOT GRUB's e/Ctrl-X editing.)
boot_command = [
  "<tab><wait>",
  " inst.text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<enter><wait>"
]
