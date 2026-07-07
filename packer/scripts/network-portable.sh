#!/usr/bin/env bash
# Make the image's network config provider-portable.
#
# The OS installer pins netplan to the NIC name present at build time (e.g.
# ens3). That name differs across providers (VirtualBox: enp0s3, libvirt/virtio:
# ens5), so on a different provider the interface never matches, never DHCPs, and
# the VM gets no IP ("Waiting for domain to get an IP address..."). Replace the
# installer's config with a match-ANY-ethernet DHCP config so the box boots on
# any provider.
#
# Ubuntu/netplan only; a no-op on Debian (ifupdown) and Rocky (NetworkManager).
# We write the file but do NOT `netplan apply` (that would drop the build SSH);
# it takes effect on the next boot.
set -uo pipefail

if [ -d /etc/netplan ]; then
  # Drop the interface-specific configs (installer + any cloud-init leftover).
  rm -f /etc/netplan/00-installer-config.yaml /etc/netplan/50-cloud-init.yaml
  cat > /etc/netplan/50-devfleet-dhcp.yaml <<'EOF'
network:
  version: 2
  ethernets:
    devfleet-any:
      match:
        name: "e*"
      dhcp4: true
      dhcp6: false
      optional: true
EOF
  chmod 600 /etc/netplan/50-devfleet-dhcp.yaml
  echo "Wrote provider-portable netplan (match e*, DHCP)."
else
  echo "No /etc/netplan (not Ubuntu) — skipping network-portable step."
fi
