#!/usr/bin/env bash
# Ensure Python 3 exists so Packer's ansible provisioner can run.
# Family detection keeps this OS-agnostic.
set -euo pipefail

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y python3 python3-apt
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y python3
elif command -v yum >/dev/null 2>&1; then
  yum install -y python3
else
  echo "No supported package manager found" >&2
  exit 1
fi

echo "Python prerequisites installed."
