#!/usr/bin/env bash
# Publish a built .box into the local box catalog with proper Vagrant versioning
# and MULTI-PROVIDER support (one box name carries virtualbox + libvirt).
#
#   scripts/publish-box.sh <os_name> <path-to.box> [version] [provider]
#     provider : virtualbox (default) | libvirt
#
# - Copies the box into boxes/<os>/ as <os>-<version>-<provider>.box
# - Merges the provider into boxes/<os>/metadata.json for that version
#   (existing providers on the same version are preserved)
# - Registers it so `vagrant box add/update` and `box_version` pinning work
#
# Version: if omitted, auto-bumps the patch of the latest version (starts 1.0.0).
#
# Hosting: metadata URLs default to file:// (local). To serve boxes to teammates,
# set DEVFLEET_BOX_BASE_URL to your HTTP root and re-publish, e.g.
#   DEVFLEET_BOX_BASE_URL=http://boxhost.example.com/boxes scripts/publish-box.sh ...
# then run scripts/serve-boxes.sh on that host.
set -euo pipefail

OS="${1:?usage: publish-box.sh <os_name> <box_file> [version] [provider]}"
BOX_SRC="${2:?missing box file path}"
VERSION_ARG="${3:-}"
PROVIDER="${4:-virtualbox}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOX_NAME="devfleet/${OS}"
DEST_DIR="$ROOT/boxes/${OS}"
META="$DEST_DIR/metadata.json"
BASE_URL="${DEVFLEET_BOX_BASE_URL:-file://$ROOT/boxes}"

[[ -f "$BOX_SRC" ]] || { echo "box not found: $BOX_SRC" >&2; exit 1; }
mkdir -p "$DEST_DIR"
CHECKSUM="$(sha256sum "$BOX_SRC" | awk '{print $1}')"

# Resolve version + merge this provider into metadata.json (preserving others).
VERSION="$(python3 - "$META" "$BOX_NAME" "$OS" "$BASE_URL" "$CHECKSUM" "$VERSION_ARG" "$PROVIDER" <<'PY'
import json, os, sys
meta_path, name, os_name, base_url, checksum, version_arg, provider = sys.argv[1:8]

meta = {"name": name, "versions": []}
if os.path.exists(meta_path):
    meta = json.load(open(meta_path))

def vkey(v): return tuple(int(x) for x in v["version"].split("."))

def bump(versions):
    if not versions:
        return "1.0.0"
    parts = max(versions, key=vkey)["version"].split(".")
    parts[-1] = str(int(parts[-1]) + 1)
    return ".".join(parts)

version = version_arg or bump(meta.get("versions", []))
url = f"{base_url}/{os_name}/{os_name}-{version}-{provider}.box"

meta.setdefault("versions", [])
entry = next((v for v in meta["versions"] if v["version"] == version), None)
if entry is None:
    entry = {"version": version, "providers": []}
    meta["versions"].append(entry)

# Replace-or-add THIS provider; keep any other providers on the version.
entry.setdefault("providers", [])
entry["providers"] = [p for p in entry["providers"] if p["name"] != provider]
entry["providers"].append({
    "name": provider, "url": url,
    "checksum_type": "sha256", "checksum": checksum,
})
entry["providers"].sort(key=lambda p: p["name"])
meta["versions"].sort(key=vkey)

with open(meta_path, "w") as f:
    json.dump(meta, f, indent=2); f.write("\n")
print(version)
PY
)"

cp -f "$BOX_SRC" "$DEST_DIR/${OS}-${VERSION}-${PROVIDER}.box"

echo ">> publishing ${BOX_NAME} v${VERSION} [${PROVIDER}] (base_url=${BASE_URL})"
# --provider avoids the interactive "which provider?" prompt when a version
# carries more than one (which would need a TTY and fail under nohup/CI).
vagrant box add --provider "$PROVIDER" --force "$META"
echo ">> published ${BOX_NAME} v${VERSION} [${PROVIDER}]"
