#!/usr/bin/env bash
#
# Vybia V2 — visual test harness.
#
# Builds the web app, serves it locally, opens headless Chrome at a mobile
# viewport, screenshots the rendered app, and prints the screenshot path.
#
# Usage:  scripts/visual_test.sh [path=/]  [outfile]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Screenshots live IN the project (./screenshots) so the founder can open them —
# never /tmp. The founder being able to open the PNG is the only proof of PASS.
OUTDIR="$ROOT/screenshots"
ROUTE="${1:-/}"
OUT="${2:-$OUTDIR/orb_demo.png}"
PORT="${PORT:-8099}"
URL="http://localhost:${PORT}/#${ROUTE}"

# Chrome on macOS.
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [[ ! -x "$CHROME" ]]; then
  echo "BLOCKED: Google Chrome not found at $CHROME" >&2
  exit 1
fi

mkdir -p "$OUTDIR"

echo "[1/4] Building web (release)…"
( cd "$ROOT" && flutter build web --release >/dev/null )

echo "[2/4] Serving build/web on :${PORT}…"
( cd "$ROOT/build/web" && python3 -m http.server "$PORT" >/dev/null 2>&1 ) &
SERVER_PID=$!
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT

# Wait for the server to answer.
for _ in $(seq 1 30); do
  if curl -sf "http://localhost:${PORT}/" >/dev/null 2>&1; then break; fi
  sleep 0.5
done

echo "[3/4] Screenshotting ${URL} (500x1084 logical @2x — mobile portrait)…"
# Headless Chrome clamps its window to a ~500px minimum logical width, and
# device-scale-factor changes density, not Flutter's logical width. So the
# tightest reliable mobile viewport is 500 logical. We set the window to exactly
# that floor with a 2x device-scale-factor so the capture width matches the
# layout width (no right-edge clipping) and renders crisply. CanvasKit needs
# time to boot + paint, hence the generous virtual-time budget.
"$CHROME" \
  --headless=new \
  --disable-gpu \
  --hide-scrollbars \
  --window-size=500,1084 \
  --force-device-scale-factor=2 \
  --virtual-time-budget=9000 \
  --screenshot="$OUT" \
  "$URL" >/dev/null 2>&1

echo "[4/4] Done."
if [[ -f "$OUT" ]]; then
  echo "SCREENSHOT: $OUT"
  # Pop the screenshot open so the founder SEES the proof.
  open "$OUT" 2>/dev/null || true
else
  echo "BLOCKED: screenshot was not written" >&2
  exit 1
fi
