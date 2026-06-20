#!/usr/bin/env bash
#
# S7 PART A — capture the orb interaction model on the /reco scene via the
# programmatic auto-drive (no pointer → no Flutter live-test crosshair). Snaps
# four named frames on their SECOND appearance (first cycle = image-decode
# warmup): rest (image + description only), contact (orb + edges together),
# hold-home warning (growing orb + warning hint), and the release shrink.
#
# Written for macOS /bin/bash 3.2 (no associative arrays).
#
# Usage: scripts/s7a_capture.sh <sim-udid>
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?usage: s7a_capture.sh <sim-udid>}"
OUT="$ROOT/screenshots"
mkdir -p "$OUT"

cleanup() { pkill -f "flutter_tools.*run" 2>/dev/null; pkill -f "flutter run" 2>/dev/null; }
trap cleanup EXIT

# name → output basename
basename_for() {
  case "$1" in
    rest) echo s7_a1_rest_clean ;;
    centre) echo s7_a2_contact_edges ;;
    hold) echo s7_a3_hold_home_warning ;;
    shrink) echo s7_a4_release_shrink ;;
    *) echo "" ;;
  esac
}

echo "[s7a] flutter run /reco (autodrive) on $SIM …"
cd "$ROOT"
xcrun simctl terminate "$SIM" com.example.vybiaV2 >/dev/null 2>&1 || true
sleep 1

# Keep flutter run's stdin open with no input (a fifo nobody writes to) so it
# doesn't quit on EOF when launched non-interactively / in the background.
FIFO="$(mktemp -u /tmp/ff_stdin.XXXXXX)"
mkfifo "$FIFO"
sleep 100000 > "$FIFO" &
SLEEP_PID=$!
cleanup() {
  kill "$SLEEP_PID" 2>/dev/null
  rm -f "$FIFO"
  pkill -f "flutter_tools.*run" 2>/dev/null
  pkill -f "flutter run" 2>/dev/null
}

flutter run -d "$SIM" \
  --dart-define=VYBIA_AUTODRIVE=true \
  --dart-define=VYBIA_START=/reco < "$FIFO" 2>&1 | (
  seen_rest=0; seen_centre=0; seen_hold=0; seen_shrink=0
  done_rest=0; done_centre=0; done_hold=0; done_shrink=0
  captured=0
  while IFS= read -r line; do
    echo "$line"
    case "$line" in
      *VYBIA_DRIVE\ *)
        name="${line##*VYBIA_DRIVE }"
        name="${name%%[[:space:]]*}"
        base="$(basename_for "$name")"
        [ -z "$base" ] && continue
        case "$name" in
          rest) seen_rest=$((seen_rest+1)); cnt=$seen_rest; dn=$done_rest ;;
          centre) seen_centre=$((seen_centre+1)); cnt=$seen_centre; dn=$done_centre ;;
          hold) seen_hold=$((seen_hold+1)); cnt=$seen_hold; dn=$done_hold ;;
          shrink) seen_shrink=$((seen_shrink+1)); cnt=$seen_shrink; dn=$done_shrink ;;
        esac
        [ "$cnt" -lt 2 ] && continue
        [ "$dn" -eq 1 ] && continue
        sleep 2.0
        if xcrun simctl io booted screenshot "$OUT/${base}.png" >/dev/null 2>&1; then
          echo "[s7a]   OK ${base}.png"
        else
          echo "[s7a]   FAIL ${base}.png"
        fi
        case "$name" in
          rest) done_rest=1 ;;
          centre) done_centre=1 ;;
          hold) done_hold=1 ;;
          shrink) done_shrink=1 ;;
        esac
        captured=$((captured+1))
        [ "$captured" -ge 4 ] && break
        ;;
    esac
  done
  echo "[s7a] captured $captured/4"
)
echo "[s7a] done."
