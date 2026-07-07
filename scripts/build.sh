#!/usr/bin/env bash
# Build a Packer box for one OS + provider(s) and publish it (versioned).
#
#   scripts/build.sh <os> [version] [provider]
#     os        : ubuntu-2404 | debian-12 | rocky-9
#     version   : explicit box version (default: auto-bump); "" for auto
#     provider  : virtualbox | libvirt | both   (default: both)
#
# Examples:
#   scripts/build.sh ubuntu-2404                 # both providers, auto version
#   scripts/build.sh ubuntu-2404 2.0.0 libvirt   # just the libvirt box at 2.0.0
#
# Publishes each built box as devfleet/<os> (same name carries both providers).
set -euo pipefail

OS="${1:?usage: build.sh <os> [version] [provider]}"
VERSION="${2:-}"
PROVIDER="${3:-both}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKER_DIR="$ROOT/packer"
VARFILE="$PACKER_DIR/${OS}.pkrvars.hcl"
[[ -f "$VARFILE" ]] || { echo "No var file: $VARFILE" >&2; exit 1; }

# provider → (packer source address, box-file suffix)
declare -A SRC=( [virtualbox]="devfleet.virtualbox-iso.vm" [libvirt]="devfleet.qemu.vm" )
case "$PROVIDER" in
  virtualbox|libvirt) targets=("$PROVIDER") ;;
  both)               targets=("virtualbox" "libvirt") ;;
  *) echo "provider must be: virtualbox | libvirt | both" >&2; exit 1 ;;
esac

only_csv="$(IFS=,; for t in "${targets[@]}"; do printf '%s,' "${SRC[$t]}"; done | sed 's/,$//')"

# Run from the repo root so Packer's output dirs land in a known place.
cd "$ROOT"

echo ">> packer init"
packer init "$PACKER_DIR"

echo ">> packer validate ($OS)"
packer validate -var-file="$VARFILE" "$PACKER_DIR"

echo ">> packer build ($OS) providers=[${targets[*]}]"
# -force: overwrite a leftover output dir from a prior/aborted run (idempotent).
packer build -force -only="$only_csv" -var-file="$VARFILE" "$PACKER_DIR"

for t in "${targets[@]}"; do
  BOX="$ROOT/builds/${OS}-${t}.box"
  echo ">> publishing devfleet/${OS} ($t)"
  "$ROOT/scripts/publish-box.sh" "$OS" "$BOX" "$VERSION" "$t"
done

# Remove Packer's raw output dirs (the box is published) — keeps disk tidy and
# lets `packer validate` / `make lint` run without "output dir exists" errors.
rm -rf "$ROOT/output-${OS}" "$ROOT/output-${OS}-qemu"

echo ">> done: devfleet/${OS} [${targets[*]}]"
