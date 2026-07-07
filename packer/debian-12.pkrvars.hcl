// Debian 12 (Bookworm) netinst — uses classic debian-installer preseed.
// Update the point release in both the URL and checksum file to match.

os_name       = "debian-12"
guest_os_type = "Debian_64"
// NOTE: Debian 12 (Bookworm) is now oldstable — 'current' points to Debian 13.
// Pinned to the 12.11.0 archive. Bump the version + checksum to move point releases.
iso_url      = "https://cdimage.debian.org/cdimage/archive/12.11.0/amd64/iso-cd/debian-12.11.0-amd64-netinst.iso"
iso_checksum = "sha256:30ca12a15cae6a1033e03ad59eb7f66a6d5a258dcf27acd115c2bd42d22640e8"

http_directory = "http/debian"

// ESC at the isolinux menu drops to a boot prompt; type the `install` label
// plus preseed params. (Battle-tested bento-style sequence.)
boot_command = [
  "<esc><wait>",
  "install <wait>",
  "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <wait>",
  "debian-installer=en_US.UTF-8 <wait>",
  "auto=true <wait>",
  "locale=en_US.UTF-8 <wait>",
  "kbd-chooser/method=us <wait>",
  "keyboard-configuration/xkb-keymap=us <wait>",
  "netcfg/get_hostname=devfleet <wait>",
  "netcfg/get_domain=local <wait>",
  "fb=false <wait>",
  "debconf/frontend=noninteractive <wait>",
  "console-setup/ask_detect=false <wait>",
  "<enter><wait>"
]
