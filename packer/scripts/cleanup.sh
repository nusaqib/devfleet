#!/usr/bin/env bash
# Shrink and sanitize the image before it becomes a box.
set -euo pipefail

# Clear package caches.
if command -v apt-get >/dev/null 2>&1; then
  apt-get -y autoremove --purge
  apt-get -y clean
  rm -rf /var/lib/apt/lists/*
elif command -v dnf >/dev/null 2>&1; then
  dnf clean all
  rm -rf /var/cache/dnf/*
fi

# Truncate logs and shell history.
find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true
rm -f /root/.bash_history /home/vagrant/.bash_history 2>/dev/null || true
unset HISTFILE

# Zero free space so the exported box compresses well.
dd if=/dev/zero of=/EMPTY bs=1M 2>/dev/null || true
rm -f /EMPTY
sync
