#!/bin/bash
# The whole Copper window for WORLD to a PNG, plus a half-size copy next to
# it (<out>.s.png) that fits in an image-reading tool.
#
#   .gauntlet/shot.sh WORLD OUT.png [CHECKOUT]
set -euo pipefail
WORLD="$1"; OUT="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
ROOT="$(cd "${3:-$(dirname "$0")/..}" && pwd)"
sleep 0.6
"$ROOT/bench" --world "$WORLD" window "$OUT" >/dev/null
sips -Z 1200 "$OUT" --out "${OUT%.png}.s.png" >/dev/null
echo "$OUT"
