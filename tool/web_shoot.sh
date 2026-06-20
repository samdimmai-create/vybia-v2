#!/bin/bash
# S9.1 Chrome visible-test harness.
#
# Serves build/web with a tiny static server, launches ONE *visible* Chrome
# window with remote debugging (its own throwaway profile, so it never touches
# the founder's main Chrome session), runs the CDP screenshot client, then
# ALWAYS cleans up (server + Chrome killed, temp profile removed) on any exit.
# Light & safe for a low-resource Mac: one server, one Chrome, no leaks.
#
# All args after the script name are forwarded to tool/cdp_capture.mjs, e.g.
#   tool/web_shoot.sh --once s9_1_chrome_smoke.png --settle 3500
#   tool/web_shoot.sh --tour --expect s9_mood,s9_q1 --settle 1600 --max-ms 150000
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PORT_HTTP="${PORT_HTTP:-8099}"
PORT_CDP="${PORT_CDP:-9222}"
URL="http://localhost:${PORT_HTTP}/"
PROFILE_DIR="$(mktemp -d /tmp/vybia_chrome.XXXXXX)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

SERVER_PID=""
CHROME_PID=""
cleanup() {
  [ -n "$CHROME_PID" ] && kill "$CHROME_PID" 2>/dev/null
  [ -n "$SERVER_PID" ] && kill "$SERVER_PID" 2>/dev/null
  pkill -f "$PROFILE_DIR" 2>/dev/null   # reap Chrome's child renderers
  rm -rf "$PROFILE_DIR" 2>/dev/null
}
trap cleanup EXIT INT TERM

if [ ! -d build/web ]; then
  echo "build/web missing — run 'flutter build web --release' first" >&2
  exit 1
fi

# 1. static server (background)
python3 -m http.server "$PORT_HTTP" --directory build/web >/tmp/vybia_http.log 2>&1 &
SERVER_PID=$!

# 2. ONE visible Chrome window with remote debugging on a throwaway profile
"$CHROME" \
  --remote-debugging-port="$PORT_CDP" \
  --user-data-dir="$PROFILE_DIR" \
  --no-first-run --no-default-browser-check --disable-extensions \
  --window-size="${WIN_W:-430},${WIN_H:-880}" --window-position=40,40 \
  --new-window "$URL" >/tmp/vybia_chrome.log 2>&1 &
CHROME_PID=$!

# 3. capture (every arg forwarded to the CDP client)
node tool/cdp_capture.mjs --port "$PORT_CDP" "$@"
exit $?
