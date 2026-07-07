#!/usr/bin/env bash
# Build a Packer box for one OS and register it locally with Vagrant.
#
#   scripts/build.sh ubuntu-2404
#   scripts/build.sh debian-12
#   scripts/build.sh rocky-9
#
# Registers the resulting box as devfleet/<os> so machines.yaml can reference it.
set -euo pipefail

OS="${1:?usage: build.sh <ubuntu-2404|debian-12|rocky-9>}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKER_DIR="$ROOT/packer"
VARFILE="$PACKER_DIR/${OS}.pkrvars.hcl"
BOX="$ROOT/builds/${OS}-virtualbox.box"

[[ -f "$VARFILE" ]] || { echo "No var file: $VARFILE" >&2; exit 1; }

echo ">> packer init"
packer init "$PACKER_DIR"

echo ">> packer validate ($OS)"
packer validate -var-file="$VARFILE" "$PACKER_DIR"

echo ">> packer build ($OS)"
# -force: overwrite a leftover output dir from a prior/aborted run (idempotent).
packer build -force -var-file="$VARFILE" "$PACKER_DIR"

echo ">> publishing box (versioned) devfleet/${OS}"
# Second arg (optional) is an explicit version; otherwise auto-bumps.
"$ROOT/scripts/publish-box.sh" "$OS" "$BOX" "${2:-}"

echo ">> done: devfleet/${OS}"
