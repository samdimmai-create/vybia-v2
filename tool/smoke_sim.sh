#!/bin/bash
# S9.1A — simulator smoke: run the app on the booted sim and capture the FIRST
# real Flutter frame (not the black iOS launch screen). macOS bash 3.2 compatible.
set -u
cd "$(dirname "$0")/.."

DEVICE=046EC953-E4FE-4B5B-973E-549072C5D720
LOG=/tmp/vybia_smoke_run.log
FIFO=/tmp/vybia_smoke_fifo
OUT=${1:-screenshots/s9_1_sim_smoke.png}
mkdir -p screenshots
rm -f "$LOG" "$FIFO"
mkfifo "$FIFO"

tail -f /dev/null > "$FIFO" &
HOLDER=$!

echo "[smoke] flutter run on $DEVICE ..."
flutter run -d "$DEVICE" < "$FIFO" > "$LOG" 2>&1 &
RUNPID=$!

cleanup() {
  echo "[smoke] stopping run ..."
  kill "$RUNPID" 2>/dev/null
  kill "$HOLDER" 2>/dev/null
  rm -f "$FIFO"
}
trap cleanup EXIT

# Wait (generously) for the Dart VM / "application started" — i.e. first frame.
echo "[smoke] waiting for app start (Dart VM) ..."
deadline=$(( $(date +%s) + 480 ))
started=0
while [ "$(date +%s)" -lt "$deadline" ]; do
  if grep -qE "Dart VM Service|A Dart VM Service|Flutter run key|To hot restart" "$LOG" 2>/dev/null; then
    started=1; break
  fi
  if grep -qiE "Error|failed to|Exception" "$LOG" 2>/dev/null; then
    if grep -qiE "Xcode build done|Building|Running" "$LOG" 2>/dev/null; then :; else
      echo "[smoke] possible early error:"; tail -20 "$LOG"
    fi
  fi
  sleep 1
done

if [ "$started" -ne 1 ]; then
  echo "[smoke] FAILED: app never started in time. Tail of log:"
  tail -40 "$LOG"
  exit 1
fi

echo "[smoke] app started; settling for first paint ..."
sleep 8
xcrun simctl io booted screenshot "$OUT" >/dev/null 2>&1
echo "[smoke] captured -> $OUT"
ls -la "$OUT"
