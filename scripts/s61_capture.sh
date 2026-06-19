#!/usr/bin/env bash
#
# S6.1 — capture the LIVE bubble under a normal `flutter run` (NOT a TestGesture),
# so the Flutter live-test pointer crosshair never appears. The scene drives the
# orb programmatically (VYBIA_AUTODRIVE) through rest → centre → 4 edges; this
# script snaps `xcrun simctl io booted screenshot` ~1.8s into each held state.
#
# Usage: scripts/s61_capture.sh <sim-udid> <route> <prefix>
#   e.g. scripts/s61_capture.sh <udid> /reco reco
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?usage: s61_capture.sh <udid> <route> <prefix>}"
ROUTE="${2:?route}"
PREFIX="${3:?prefix}"
OUT="$ROOT/screenshots"
mkdir -p "$OUT"

cleanup() { pkill -f "flutter_tools.*run" 2>/dev/null; pkill -f "flutter run" 2>/dev/null; }
trap cleanup EXIT

echo "[s61] flutter run $ROUTE (autodrive) on $SIM …"
cd "$ROOT"

script -q /dev/null flutter run -d "$SIM" \
  --dart-define=VYBIA_AUTODRIVE=true \
  --dart-define=VYBIA_START="$ROUTE" 2>&1 | (
  captured=" "
  count=0
  while IFS= read -r line; do
    echo "$line"
    case "$line" in
      *VYBIA_DRIVE\ *)
        name="$(printf '%s' "$line" | sed -n 's/.*VYBIA_DRIVE \([a-z]*\).*/\1/p')"
        [ -n "$name" ] || continue
        count=$((count + 1))
        # Skip the first full cycle (6 markers) so the image is fully loaded.
        [ "$count" -le 6 ] && continue
        case "$captured" in
          *" $name "*) : ;; # already captured this state
          *)
            captured="$captured$name "
            ( sleep 2.5
              xcrun simctl io booted screenshot "$OUT/drive_${PREFIX}_${name}.png" >/dev/null 2>&1 \
                && echo "[s61]   OK drive_${PREFIX}_${name}.png" \
                || echo "[s61]   FAIL capture ${name}" ) &
            ;;
        esac
        ncap=$(printf '%s' "$captured" | wc -w | tr -d ' ')
        if [ "$ncap" -ge 6 ]; then
          sleep 3
          echo "[s61] all states captured for $PREFIX"
          break
        fi
        ;;
    esac
  done
  wait
)
echo "[s61] done."
