#!/bin/bash
# S8.1 visible proof capture on the booted iOS simulator.
# Runs the app with the VYBIA_PROOF81 tour, then screenshots each deterministic
# stop synced to its `VYBIA_PROOF <name>` marker. macOS bash 3.2 compatible.
set -u
cd "$(dirname "$0")/.."

DEVICE=046EC953-E4FE-4B5B-973E-549072C5D720
LOG=/tmp/vybia_s8_1_run.log
FIFO=/tmp/vybia_s8_1_fifo
SHOTS=screenshots
mkdir -p "$SHOTS"
rm -f "$LOG" "$FIFO"
mkfifo "$FIFO"

# Hold the fifo's write end open so `flutter run` keeps its interactive stdin.
tail -f /dev/null > "$FIFO" &
HOLDER=$!

echo "[capture] launching flutter run on $DEVICE ..."
flutter run -d "$DEVICE" --dart-define=VYBIA_PROOF81=true < "$FIFO" > "$LOG" 2>&1 &
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

shoot() { # marker file
  echo "[capture] $1 -> $2"
  xcrun simctl io booted screenshot "$SHOTS/$2" >/dev/null 2>&1
}

# 1. Wait (long) for the build+install+launch and the first tour marker.
echo "[capture] waiting for app launch (first marker) ..."
if ! wait_marker orb_compare 420; then
  echo "[capture] FAILED: app never reached the tour. Tail of log:"
  tail -30 "$LOG"
  exit 1
fi

# The tour cycles every 7s. For each stop wait until it's current, settle, shoot.
sleep 2;                            shoot orb_compare        s8_1_orb_size_compare.png
wait_marker card_rest 60          && sleep 2 && shoot card_rest          s8_1_card_rest.png
wait_marker card_contact 60       && sleep 2 && shoot card_contact       s8_1_card_contact.png
wait_marker edge_wave_joy 60      && sleep 2 && shoot edge_wave_joy      s8_1_edge_wave_joy.png
wait_marker edge_wave_reject 60   && sleep 2 && shoot edge_wave_reject   s8_1_edge_wave_reject.png
wait_marker edge_wave_curious 60  && sleep 2 && shoot edge_wave_curious  s8_1_edge_wave_curious.png
wait_marker edge_wave_go 60       && sleep 2 && shoot edge_wave_go       s8_1_edge_wave_go.png
wait_marker reflection_explore 60 && sleep 2 && shoot reflection_explore s8_1_reflection_explore.png
wait_marker reflection_plan 60    && sleep 2 && shoot reflection_plan    s8_1_reflection_plan.png
wait_marker hold_warning 60       && sleep 2 && shoot hold_warning       s8_1_hold_warning.png
wait_marker hold_portal 60        && sleep 3 && shoot hold_portal        s8_1_hold_portal.png
wait_marker home_landed 60        && sleep 2 && shoot home_landed        s8_1_home_landed.png

# back-from-reco lands on the calm Accueil (reco's parent route) — capture the
# reco scene we go back FROM as the companion frame.
cp "$SHOTS/s8_1_card_rest.png" "$SHOTS/s8_1_back_from_reco.png" 2>/dev/null

echo "[capture] done. Files:"
ls -la "$SHOTS"/s8_1_*.png
