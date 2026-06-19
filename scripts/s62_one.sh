#!/usr/bin/env bash
#
# S6.2 — capture ONE lens variant on ONE route's centre state (pure glass
# droplet). Lands DIRECTLY on the route with VYBIA_START (no splash→welcome
# race, no scene-hop ambiguity) and snaps the 'centre' state on its SECOND
# appearance (first cycle = image-decode warmup), then exits. Programmatic
# auto-drive → no pointer → no Flutter live-test crosshair.
#
# Usage: scripts/s62_one.sh <sim-udid> <vif|calm> <route> <out-basename>
#   e.g. scripts/s62_one.sh <udid> calm /reco s6_2_calm_reco
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?usage: s62_one.sh <udid> <vif|calm> <route> <out-basename>}"
LENS="${2:?lens}"
ROUTE="${3:?route}"
BASE="${4:?out-basename}"
OUT="$ROOT/screenshots"
mkdir -p "$OUT"

cleanup() { pkill -f "flutter_tools.*run" 2>/dev/null; pkill -f "flutter run" 2>/dev/null; }
trap cleanup EXIT

echo "[s62one] flutter run $ROUTE (autodrive, lens=$LENS) on $SIM …"
cd "$ROOT"

# Terminate any previous app instance first: otherwise `flutter run` may attach
# to the still-running app (wrong dart-defines/route) and the screenshot catches
# that stale scene instead of the freshly-launched route.
xcrun simctl terminate "$SIM" com.example.vybiaV2 >/dev/null 2>&1 || true
sleep 1

script -q /dev/null flutter run -d "$SIM" \
  --dart-define=VYBIA_AUTODRIVE=true \
  --dart-define=VYBIA_LENS="$LENS" \
  --dart-define=VYBIA_START="$ROUTE" 2>&1 | (
  centre_seen=0
  while IFS= read -r line; do
    echo "$line"
    case "$line" in
      *VYBIA_DRIVE\ centre*)
        centre_seen=$((centre_seen + 1))
        [ "$centre_seen" -lt 2 ] && continue   # skip first cycle (decode warmup)
        sleep 2.5
        if xcrun simctl io booted screenshot "$OUT/${BASE}.png" >/dev/null 2>&1; then
          echo "[s62one]   OK ${BASE}.png"
        else
          echo "[s62one]   FAIL ${BASE}.png"
        fi
        sleep 0.5
        break
        ;;
    esac
  done
)
echo "[s62one] done ($BASE)."
