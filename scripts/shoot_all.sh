#!/usr/bin/env bash
#
# Vybia V2 — multi-route screenshot pass (timeout-hardened, never blocks).
#
# Assumes `flutter build web --release` already ran. Serves build/web in the
# BACKGROUND, waits at most ~20s for it to answer, screenshots every route under
# a hard per-shot watchdog, ALWAYS kills the server, and self-terminates within
# ~90s even on failure. macOS has no `timeout`, so we use a bash watchdog.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTDIR="$ROOT/screenshots"
PORT="${PORT:-8099}"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[[ -x "$CHROME" ]] || { echo "BLOCKED: Chrome not found" >&2; exit 1; }
mkdir -p "$OUTDIR"

# Run "$@" but kill it after $1 seconds. Returns 124 on timeout.
run_for() {
  local secs="$1"; shift
  "$@" & local pid=$!
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 1; i=$((i+1))
    if [[ $i -ge $secs ]]; then
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      return 124
    fi
  done
  wait "$pid" 2>/dev/null
}

# Start server in background; always reap it on exit.
( cd "$ROOT/build/web" && exec python3 -m http.server "$PORT" ) >/dev/null 2>&1 &
SERVER_PID=$!
cleanup() {
  kill -9 "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

# Wait up to 20s for the server to answer.
ready=0
for _ in $(seq 1 40); do
  if curl -sf "http://localhost:${PORT}/" >/dev/null 2>&1; then ready=1; break; fi
  sleep 0.5
done
if [[ "$ready" != 1 ]]; then
  echo "BLOCKED: server did not answer on :${PORT} within 20s" >&2
  exit 1
fi

shoot() {
  local route="$1" out="$OUTDIR/$2"
  echo "  • $route → $2"
  run_for 20 "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --no-first-run --no-default-browser-check \
    --window-size=500,1084 --force-device-scale-factor=2 \
    --virtual-time-budget=9000 --screenshot="$out" \
    "http://localhost:${PORT}/#${route}"
  local rc=$?
  if [[ $rc -eq 124 ]]; then echo "    ! timed out (kept whatever was written)"; fi
  [[ -f "$out" ]] && echo "    ✓ $(stat -f%z "$out" 2>/dev/null) bytes" || echo "    ✗ no file"
}

shoot "/welcome"     "s3_welcome.png"
shoot "/discover"    "s3_discover.png"
shoot "/intention"   "s3_intention.png"
shoot "/reco"        "s3_reco.png"
shoot "/plan"        "s3_plan.png"
shoot "/dev"         "s3_dev.png"

echo "Done. Screenshots in $OUTDIR"
open "$OUTDIR"/s3_*.png 2>/dev/null || true
