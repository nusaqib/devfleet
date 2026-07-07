#!/usr/bin/env bash
# Publish a built .box into the local box catalog with proper Vagrant versioning.
#
#   scripts/publish-box.sh <os_name> <path-to.box> [version]
#
# - Copies the box into boxes/<os>/ as <os>-<version>.box
# - Regenerates boxes/<os>/metadata.json (Vagrant box metadata, versioned)
# - Registers it so `vagrant box add/update` and `box_version` pinning work
#
# Version: if omitted, auto-bumps the patch of the latest version in metadata
# (starts at 1.0.0). Explicit semver-ish versions are accepted.
#
# Hosting: metadata URLs default to file:// (local). To serve boxes to teammates,
# set DEVFLEET_BOX_BASE_URL to your HTTP root and re-publish, e.g.
#   DEVFLEET_BOX_BASE_URL=http://boxhost.example.com/boxes scripts/publish-box.sh ...
# then run scripts/serve-boxes.sh on that host.
set -euo pipefail

OS="${1:?usage: publish-box.sh <os_name> <box_file> [version]}"
BOX_SRC="${2:?missing box file path}"
VERSION_ARG="${3:-}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOX_NAME="devfleet/${OS}"
DEST_DIR="$ROOT/boxes/${OS}"
META="$DEST_DIR/metadata.json"
BASE_URL="${DEVFLEET_BOX_BASE_URL:-file://$ROOT/boxes}"

[[ -f "$BOX_SRC" ]] || { echo "box not found: $BOX_SRC" >&2; exit 1; }
mkdir -p "$DEST_DIR"

CHECKSUM="$(sha256sum "$BOX_SRC" | awk '{print $1}')"

# Compute version + rewrite metadata.json atomically via python.
python3 - "$META" "$BOX_NAME" "$OS" "$BASE_URL" "$CHECKSUM" "$VERSION_ARG" <<'PY'
import json, os, sys
meta_path, name, os_name, base_url, checksum, version_arg = sys.argv[1:7]

meta = {"name": name, "versions": []}
if os.path.exists(meta_path):
    with open(meta_path) as f:
        meta = json.load(f)

def bump(versions):
    if not versions:
        return "1.0.0"
    # Highest existing version by numeric tuple, bump last component.
    def key(v):
        return tuple(int(x) for x in v["version"].split("."))
    latest = max(versions, key=key)["version"]
    parts = latest.split(".")
    parts[-1] = str(int(parts[-1]) + 1)
    return ".".join(parts)

version = version_arg or bump(meta.get("versions", []))
url = f"{base_url}/{os_name}/{os_name}-{version}.box"

# Drop any existing entry for this version, then add fresh.
meta.setdefault("versions", [])
meta["versions"] = [v for v in meta["versions"] if v["version"] != version]
meta["versions"].append({
    "version": version,
    "providers": [{
        "name": "virtualbox",
        "url": url,
        "checksum_type": "sha256",
        "checksum": checksum,
    }],
})
# Keep sorted for readability.
meta["versions"].sort(key=lambda v: tuple(int(x) for x in v["version"].split(".")))

with open(meta_path, "w") as f:
    json.dump(meta, f, indent=2)
    f.write("\n")
print(version)
PY

VERSION="$(python3 -c "import json,sys;print(max(json.load(open('$META'))['versions'],key=lambda v:tuple(int(x) for x in v['version'].split('.')))['version'])")"
cp -f "$BOX_SRC" "$DEST_DIR/${OS}-${VERSION}.box"

echo ">> publishing ${BOX_NAME} v${VERSION} (base_url=${BASE_URL})"
vagrant box add --force "$META"
echo ">> published ${BOX_NAME} v${VERSION}"
