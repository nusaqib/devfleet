#!/usr/bin/env bash
# Install VirtualBox Guest Additions so native shared folders / clipboard work.
# Packer uploads VBoxGuestAdditions.iso into the guest (guest_additions_mode=upload);
# this finds it, installs kernel-build prerequisites, and runs the installer.
#
# NOTE: VBoxLinuxAdditions.run commonly exits non-zero on headless systems because
# it can't build the X11/OpenGL bits — that's fine. We treat success as "the vboxsf
# kernel module is present afterwards", not the installer's exit code.
set -uo pipefail

# 1. Locate the uploaded ISO.
ISO=""
for cand in /home/vagrant/VBoxGuestAdditions.iso /root/VBoxGuestAdditions.iso \
            /tmp/VBoxGuestAdditions.iso ./VBoxGuestAdditions.iso; do
  [[ -f "$cand" ]] && { ISO="$cand"; break; }
done
if [[ -z "$ISO" ]]; then
  echo "Guest Additions ISO not found in guest; skipping." >&2
  exit 0
fi
echo "Using Guest Additions ISO: $ISO"

# 2. Install build prerequisites (family-aware).
if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y build-essential dkms "linux-headers-$(uname -r)"
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y gcc make perl dkms elfutils-libelf-devel \
    "kernel-devel-$(uname -r)" "kernel-headers-$(uname -r)" || \
    dnf install -y gcc make perl dkms elfutils-libelf-devel kernel-devel kernel-headers
fi

# 3. Mount and run the installer.
MNT="$(mktemp -d)"
mount -o loop,ro "$ISO" "$MNT"
sh "$MNT/VBoxLinuxAdditions.run" --nox11 || echo "GA installer returned non-zero (expected on headless) — verifying modules..."
umount "$MNT"; rmdir "$MNT"
rm -f "$ISO"

# 4. Check whether the shared-folder module built. This is BEST-EFFORT: some
# OS/kernel/GA-version combos (e.g. VBox 7.1 GA vs newer RHEL 9 kernels) fail to
# compile the modules. We do NOT fail the build on that — the box still works,
# it just falls back to rsync synced folders instead of native vboxsf. We write
# a marker so the Vagrant layer / humans can tell which boxes got native GA.
if modinfo vboxsf >/dev/null 2>&1 || modinfo vboxguest >/dev/null 2>&1; then
  echo "Guest Additions installed: vboxsf/vboxguest module present."
  echo "ok" > /etc/devfleet-guest-additions
else
  echo "WARNING: Guest Additions modules did not build on this OS/kernel." >&2
  echo "         Box will use rsync synced folders instead of native vboxsf." >&2
  echo "failed" > /etc/devfleet-guest-additions
fi
exit 0
