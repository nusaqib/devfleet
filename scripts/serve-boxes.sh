#!/usr/bin/env bash
# Serve the box catalog over HTTP so teammates can pull versioned boxes.
#
#   scripts/serve-boxes.sh [port]        # default 8099
#
# On the SERVING host, (re)publish boxes with the matching base URL so the
# metadata points at HTTP instead of file://, e.g.:
#   DEVFLEET_BOX_BASE_URL=http://$(hostname -f):8099 scripts/build.sh ubuntu-2404
#
# Teammates then add a box by pointing Vagrant at its metadata.json:
#   vagrant box add http://boxhost:8099/ubuntu-2404/metadata.json
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${1:-8099}"
cd "$ROOT/boxes" 2>/dev/null || { echo "No boxes/ yet — build something first." >&2; exit 1; }
echo ">> serving $ROOT/boxes at http://0.0.0.0:${PORT}/  (Ctrl-C to stop)"
exec python3 -m http.server "$PORT"
