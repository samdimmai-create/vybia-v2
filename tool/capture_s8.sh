#!/bin/bash
# S8 visible proof capture on the booted iOS simulator.
# Runs the app with the VYBIA_PROOF tour, then screenshots each deterministic
# stop synced to its `VYBIA_PROOF <name>` marker. macOS bash 3.2 compatible.
set -u
cd "$(dirname "$0")/.."

DEVICE=046EC953-E4FE-4B5B-973E-549072C5D720
LOG=/tmp/vybia_s8_run.log
FIFO=/tmp/vybia_s8_fifo
SHOTS=screenshots
mkdir -p "$SHOTS"
rm -f "$LOG" "$FIFO"
mkfifo "$FIFO"

# Hold the fifo's write end open so `flutter run` keeps its interactive stdin.
tail -f /dev/null > "$FIFO" &
HOLDER=$!

echo "[capture] launching flutter run on $DEVICE ..."
flutter run -d "$DEVICE" --dart-define=VYBIA_PROOF=true < "$FIFO" > "$LOG" 2>&1 &
RUNPID=$!

cleanup() {
  echo "[capture] stopping run ..."
  kill "$RUNPID" 2>/dev/null
  kill "$HOLDER" 2>/dev/null
  rm -f "$FIFO"
}
trap cleanup EXIT

last_marker() { grep "VYBIA_PROOF" "$LOG" 2>/dev/null | tail -1 | awk '{print $NF}'; }

wait_marker() {
  target="$1"; budget="$2"
  deadline=$(( $(date +%s) + budget ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if [ "$(last_marker)" = "$target" ]; then return 0; fi
    sleep 0.4
  done
  return 1
}

shoot() { # name file
  echo "[capture] $1 -> $2"
  xcrun simctl io booted screenshot "$SHOTS/$2" >/dev/null 2>&1
}

# 1. Wait (long) for the build+install+launch and the first tour marker.
echo "[capture] waiting for app launch (first marker) ..."
if ! wait_marker accueil 360; then
  echo "[capture] FAILED: app never reached the tour. Tail of log:"
  tail -30 "$LOG"
  exit 1
fi

# The tour cycles every 7s: accueil, reco_cafe, reco_theatre, hold, throw.
# For each, wait until that stop is current, let it settle/animate, screenshot.
sleep 2;  shoot accueil      s8_accueil_calm.png
wait_marker reco_cafe 60     && sleep 2 && shoot reco_cafe     s8_reco_cafe.png
wait_marker reco_theatre 60  && sleep 2 && shoot reco_theatre  s8_reco_theatre.png
wait_marker hold 60          && sleep 3 && shoot hold          s8_hold_to_home_calm.png
wait_marker throw 60         && sleep 2 && shoot throw         s8_throw_commit.png

echo "[capture] done. Files:"
ls -la "$SHOTS"/s8_*.png
