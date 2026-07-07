#!/usr/bin/env bash
# Install the QEMU guest agent so libvirt/host can query & manage the guest
# (graceful shutdown, IP reporting, fs-freeze). Family-aware; best-effort.
set -uo pipefail

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y qemu-guest-agent
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y qemu-guest-agent
else
  echo "No supported package manager; skipping qemu-guest-agent." >&2
  exit 0
fi

systemctl enable qemu-guest-agent 2>/dev/null || true
echo "qemu-guest-agent installed."
