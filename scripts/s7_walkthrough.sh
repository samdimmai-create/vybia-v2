#!/usr/bin/env bash
#
# S7 PART D — consolidated rest-state walkthrough on the iOS simulator. Captures
# a sequence of screens, one per spec, each launched directly via VYBIA_START,
# settled, snapped, and quit. macOS /bin/bash 3.2 compatible (no `script`, no
# `timeout`); stdin kept open via a fifo so `flutter run` survives non-interactive.
#
# Each spec: "route|out-basename|extra-dart-defines|wait-s"  (| separated)
#   extra-dart-defines: space-separated --dart-define=... (or empty)
#
# Usage: scripts/s7_walkthrough.sh <sim-udid> <spec> [<spec> ...]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?usage: s7_walkthrough.sh <sim-udid> <spec>...}"; shift
OUT="$ROOT/screenshots"; mkdir -p "$OUT"; cd "$ROOT"

FIFO="$(mktemp -u /tmp/ff_stdin.XXXXXX)"; mkfifo "$FIFO"
sleep 100000 > "$FIFO" & SLEEP_PID=$!
cleanup() {
  kill "$SLEEP_PID" 2>/dev/null; rm -f "$FIFO"
  pkill -f "flutter_tools.*run" 2>/dev/null; pkill -f "flutter run" 2>/dev/null
}
trap cleanup EXIT

shoot() {
  local route="$1" base="$2" defines="$3" wait="${4:-14}"
  echo "[wt] $route -> ${base}.png (defines='${defines}')"
  xcrun simctl terminate "$SIM" com.example.vybiaV2 >/dev/null 2>&1 || true
  sleep 1
  # shellcheck disable=SC2086
  flutter run -d "$SIM" --dart-define=VYBIA_START="$route" $defines < "$FIFO" 2>&1 | (
    while IFS= read -r line; do
      case "$line" in
        *"Flutter DevTools"*|*"is available at"*)
          sleep "$wait"
          if xcrun simctl io booted screenshot "$OUT/${base}.png" >/dev/null 2>&1; then
            echo "[wt]   OK ${base}.png"
          else
            echo "[wt]   FAIL ${base}.png"
          fi
          break ;;
      esac
    done
  )
  pkill -f "flutter_tools.*run" 2>/dev/null; pkill -f "flutter run" 2>/dev/null
  sleep 2
}

for spec in "$@"; do
  IFS='|' read -r route base defines wait <<< "$spec"
  shoot "$route" "$base" "${defines:-}" "${wait:-14}"
done
echo "[wt] all done."
