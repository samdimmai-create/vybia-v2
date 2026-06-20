#!/usr/bin/env bash
# Poll a growing flutter-run autodrive log and snap each wanted drive state to
# screenshots/<prefix>_<state>.png on its SECOND marker (first = decode warmup).
# Usage: s63_poll.sh <sim-udid> <logfile> <prefix> "<states>"   [CAP_SECONDS env]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?udid}"; LOG="${2:?log}"; PREFIX="${3:?prefix}"; WANTED="${4:?states}"
OUT="$ROOT/screenshots"; CAP="${CAP_SECONDS:-200}"; mkdir -p "$OUT"
start=$(date +%s); captured=" "
echo "[poll] want:$WANTED from $LOG"
while :; do
  now=$(date +%s); [ $((now-start)) -gt "$CAP" ] && { echo "[poll] CAP hit captured:$captured"; break; }
  [ -f "$LOG" ] || { sleep 1; continue; }
  for st in $WANTED; do
    case "$captured" in *" $st "*) continue ;; esac
    n=$(grep -c "VYBIA_DRIVE $st\b" "$LOG" 2>/dev/null); n="${n:-0}"
    if [ "$n" -ge 2 ]; then
      sleep 1
      if xcrun simctl io booted screenshot "$OUT/${PREFIX}_${st}.png" >/dev/null 2>&1; then
        echo "[poll]   OK ${PREFIX}_${st}.png"; captured="$captured$st "
      else echo "[poll]   FAIL ${PREFIX}_${st}.png"; fi
    fi
  done
  done_all=1; for w in $WANTED; do case "$captured" in *" $w "*) : ;; *) done_all=0 ;; esac; done
  [ "$done_all" -eq 1 ] && { echo "[poll] all captured"; break; }
  sleep 2
done
echo "[poll] done ($PREFIX): $captured"
