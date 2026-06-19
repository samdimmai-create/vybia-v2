#!/usr/bin/env bash
#
# S6 — run the held-orb integration test on the booted iOS simulator and capture
# each held frame with `xcrun simctl io booted screenshot` when the test prints
# its marker line `VYBIA_SHOT <name>`. App/simulator-targeted capture only; no
# OS cursor/keyboard injection (gestures are framework-level inside the test).
#
# Usage: scripts/s6_capture.sh <sim-udid>
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?usage: s6_capture.sh <sim-udid>}"
OUTDIR="$ROOT/screenshots"
mkdir -p "$OUTDIR"

echo "[s6] running held-orb test on $SIM …"
cd "$ROOT"
flutter test integration_test/s6_held_test.dart -d "$SIM" 2>&1 | while IFS= read -r line; do
  echo "$line"
  case "$line" in
    *VYBIA_SHOT\ *)
      name="$(printf '%s\n' "$line" | sed -n 's/.*VYBIA_SHOT \([a-z0-9_]*\).*/\1/p')"
      [ -n "$name" ] || continue
      # Snap ~2.8s into the ~6.6s hold so the frame is steady.
      ( sleep 2.8; xcrun simctl io booted screenshot "$OUTDIR/$name.png" >/dev/null 2>&1 \
        && echo "[s6]   ✓ captured $name.png" || echo "[s6]   ✗ capture failed $name" ) &
      ;;
    *VYBIA_SHOTS_DONE*) echo "[s6] all markers emitted" ;;
  esac
done

wait
echo "[s6] done. screenshots in $OUTDIR"