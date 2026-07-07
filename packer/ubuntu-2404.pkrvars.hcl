// Ubuntu 24.04 LTS (Noble) — uses Subiquity autoinstall (cloud-init nocloud).
// Bump the point release + it auto-fetches the matching checksum from SHA256SUMS.

os_name       = "ubuntu-2404"
guest_os_type = "Ubuntu_64"
iso_url       = "https://releases.ubuntu.com/24.04/ubuntu-24.04.4-live-server-amd64.iso"
iso_checksum  = "sha256:e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"

http_directory = "http/ubuntu"

// GRUB: edit the boot entry, append autoinstall + the nocloud datasource, boot.
boot_command = [
  "<wait><wait><wait><esc><wait><wait><wait>",
  "e<wait>",
  "<down><down><down><end>",
  " autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
  "<wait><f10><wait>"
]
