#!/usr/bin/env bash
#
# S6.3 — land on ONE route (VYBIA_START, no splash/hop race), programmatic orb
# auto-drive (no pointer → no Flutter live-test crosshair), and snap each wanted
# drive state to screenshots/<prefix>_<state>.png on its SECOND appearance
# (first cycle = image-decode warmup). Exits once every wanted state is shot or
# the time cap is hit.
#
# Usage: scripts/s63_capture.sh <sim-udid> <route> <prefix> "<state> <state> …"
#   e.g. scripts/s63_capture.sh <udid> /reco s6_3_reco "rest centre left right up down"
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?usage: s63_capture.sh <udid> <route> <prefix> \"<states>\"}"
ROUTE="${2:?route}"
PREFIX="${3:?prefix}"
WANTED="${4:?wanted states}"
OUT="$ROOT/screenshots"
CAP_SECONDS="${CAP_SECONDS:-240}"
mkdir -p "$OUT"

cleanup() { pkill -f "flutter_tools.*run" 2>/dev/null; pkill -f "flutter run" 2>/dev/null; }
trap cleanup EXIT

echo "[s63] flutter run $ROUTE (autodrive) on $SIM — want: $WANTED (cap ${CAP_SECONDS}s)"
cd "$ROOT"

# Terminate any previous app instance first so `flutter run` launches fresh
# (else it may attach to a stale app with the wrong route/defines).
xcrun simctl terminate "$SIM" com.example.vybiaV2 >/dev/null 2>&1 || true
sleep 1

START_TS=$(date +%s)

script -q /dev/null flutter run -d "$SIM" \
  --dart-define=VYBIA_AUTODRIVE=true \
  --dart-define=VYBIA_START="$ROUTE" 2>&1 | (
  seen=" "        # "<state>:<count>" tally
  captured=" "    # states already shot
  while IFS= read -r line; do
    echo "$line"
    now=$(date +%s)
    if [ $((now - START_TS)) -gt "$CAP_SECONDS" ]; then
      echo "[s63] TIME CAP hit — captured:$captured"
      break
    fi
    case "$line" in
      *VYBIA_DRIVE\ *)
        st="$(printf '%s' "$line" | sed -n 's/.*VYBIA_DRIVE \([a-z]*\).*/\1/p')"
        [ -n "$st" ] || continue
        case " $WANTED " in *" $st "*) : ;; *) continue ;; esac   # not wanted
        case "$captured" in *" $st "*) continue ;; esac           # already shot
        # count sightings; skip the first (decode warmup)
        c=$(printf '%s' "$seen" | tr ' ' '\n' | grep -c "^${st}:" 2>/dev/null || echo 0)
        seen="$seen${st}:$((c + 1)) "
        [ "$c" -lt 1 ] && continue
        sleep 2.2
        if xcrun simctl io booted screenshot "$OUT/${PREFIX}_${st}.png" >/dev/null 2>&1; then
          echo "[s63]   OK ${PREFIX}_${st}.png"
          captured="$captured$st "
        else
          echo "[s63]   FAIL ${PREFIX}_${st}.png"
        fi
        # all wanted captured?
        done_all=1
        for w in $WANTED; do
          case "$captured" in *" $w "*) : ;; *) done_all=0 ;; esac
        done
        [ "$done_all" -eq 1 ] && { echo "[s63] all wanted captured"; break; }
        ;;
    esac
  done
)
echo "[s63] done ($PREFIX)."
