#!/usr/bin/env bash
#
# S7 — capture a single screen at REST (hero image + description, no orb) on the
# iOS simulator. Lands directly on a route via VYBIA_START, waits for it to
# settle, snaps once and quits. Optional geo override drives distance-aware reco.
#
# macOS /bin/bash 3.2 compatible. No `script` (needs a TTY), no `timeout`.
#
# Usage: scripts/s7_shot.sh <sim-udid> <route> <out-basename> [geo lat,lng] [wait-s]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?usage: s7_shot.sh <sim-udid> <route> <out-basename> [lat,lng] [wait-s]}"
ROUTE="${2:?route}"
BASE="${3:?out-basename}"
GEO="${4:-}"
WAIT="${5:-14}"
OUT="$ROOT/screenshots"
mkdir -p "$OUT"
cd "$ROOT"

FIFO="$(mktemp -u /tmp/ff_stdin.XXXXXX)"; mkfifo "$FIFO"
sleep 100000 > "$FIFO" & SLEEP_PID=$!
cleanup() {
  kill "$SLEEP_PID" 2>/dev/null; rm -f "$FIFO"
  pkill -f "flutter_tools.*run" 2>/dev/null; pkill -f "flutter run" 2>/dev/null
}
trap cleanup EXIT

xcrun simctl terminate "$SIM" com.example.vybiaV2 >/dev/null 2>&1 || true
sleep 1

GEO_DEFINE=()
[ -n "$GEO" ] && GEO_DEFINE=(--dart-define=VYBIA_GEO="$GEO")

echo "[shot] $ROUTE geo='${GEO:-none}' -> ${BASE}.png"
flutter run -d "$SIM" \
  --dart-define=VYBIA_START="$ROUTE" \
  "${GEO_DEFINE[@]}" < "$FIFO" 2>&1 | (
  while IFS= read -r line; do
    echo "$line"
    case "$line" in
      *"Flutter DevTools"*|*"Syncing files"*|*"is available at"*)
        sleep "$WAIT"
        if xcrun simctl io booted screenshot "$OUT/${BASE}.png" >/dev/null 2>&1; then
          echo "[shot]   OK ${BASE}.png"
        else
          echo "[shot]   FAIL ${BASE}.png"
        fi
        break
        ;;
    esac
  done
)
echo "[shot] done ($BASE)."
