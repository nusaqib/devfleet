// Variable declarations shared by all OS sources.
// Per-OS values live in *.pkrvars.hcl and are passed with `-var-file`.

variable "os_name" {
  type        = string
  description = "Short OS identifier, e.g. ubuntu-2404. Used for the output box name."
}

variable "iso_url" {
  type        = string
  description = "URL (or file path) to the installer ISO."
}

variable "iso_checksum" {
  type        = string
  description = "ISO checksum, e.g. 'file:https://.../SHA256SUMS' to auto-fetch."
}

variable "guest_os_type" {
  type        = string
  description = "VirtualBox guest OS type, e.g. Ubuntu_64, Debian_64, RedHat_64."
}

variable "boot_command" {
  type        = list(string)
  description = "Keystrokes to kick off the unattended install for this OS."
}

variable "http_directory" {
  type        = string
  description = "Dir served over HTTP to the installer (autoinstall/preseed/kickstart)."
}

variable "ssh_username" {
  type    = string
  default = "vagrant"
}

variable "ssh_password" {
  type    = string
  default = "vagrant"
}

// Hardware defaults — override per OS if needed.
variable "cpus" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 2048
}

variable "disk_size" {
  type    = number
  default = 40000 // MB
}

variable "headless" {
  type    = bool
  default = true
}
