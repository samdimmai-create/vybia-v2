#!/usr/bin/env bash
# ============================================================================
# Vybia V2 — one-command rebuild + redeploy.
#
# The founder tests Vybia by opening a PUBLIC URL on his iPHONE (or another
# computer). This Mac's Intel Iris GPU kernel-panics on heavy rendering, so:
#   - this script does CPU work ONLY: `flutter build web` + static serve + tunnel
#   - it NEVER runs `flutter run`, NEVER opens the app in Chrome / the simulator.
#
# Host: Cloudflare "quick tunnel" — zero account, instant public URL.
#   Trade-off: the URL lives only while this Mac is on AND this script runs.
#   For a permanent URL that works with the Mac off, see ./reports (S13) for the
#   one optional 2-minute signup (Netlify/Surge token in tool/secrets.env).
#
# Usage:   ./tool/deploy.sh          # rebuild + serve + tunnel, prints URL, stays up
#          VYBIA_PORT=9000 ./tool/deploy.sh
# ============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

PORT="${VYBIA_PORT:-8787}"
SERVE_DIR="$PROJECT_DIR/build/web"
LOG_DIR="$PROJECT_DIR/.tmp"
mkdir -p "$LOG_DIR"
TUNNEL_LOG="$LOG_DIR/cloudflared.log"

# Optional API keys live ONLY here, gitignored. Absent by design (keyless build):
# Open-Meteo weather + Montreal open-data events are keyless; place enrichment is
# baked at ingest time. TMDB / Ticketmaster stay in standby until keys are set.
if [ -f tool/secrets.env ]; then set -a; . tool/secrets.env; set +a; fi

DEFINES=""
[ -n "${GEOAPIFY_KEY:-}" ]     && DEFINES="$DEFINES --dart-define=GEOAPIFY_KEY=$GEOAPIFY_KEY"
[ -n "${FOURSQUARE_KEY:-}" ]   && DEFINES="$DEFINES --dart-define=FOURSQUARE_KEY=$FOURSQUARE_KEY"
[ -n "${TMDB_KEY:-}" ]         && DEFINES="$DEFINES --dart-define=TMDB_KEY=$TMDB_KEY"
[ -n "${TICKETMASTER_KEY:-}" ] && DEFINES="$DEFINES --dart-define=TICKETMASTER_KEY=$TICKETMASTER_KEY"

echo "==> Building Flutter web (release, base-href /)…"
# shellcheck disable=SC2086
flutter build web --release --base-href / $DEFINES

# Stop any previous server / tunnel on this port.
pkill -f "http.server ${PORT}" 2>/dev/null || true
pkill -f "cloudflared tunnel"  2>/dev/null || true
sleep 1

echo "==> Serving $SERVE_DIR on :$PORT (static, CPU only — no rendering)…"
( cd "$SERVE_DIR" && exec python3 -m http.server "$PORT" >/dev/null 2>&1 ) &
SERVE_PID=$!

echo "==> Opening Cloudflare quick tunnel…"
: > "$TUNNEL_LOG"
cloudflared tunnel --url "http://localhost:${PORT}" >"$TUNNEL_LOG" 2>&1 &
TUNNEL_PID=$!

URL=""
for _ in $(seq 1 40); do
  URL="$(grep -Eo 'https://[a-z0-9-]+\.trycloudflare\.com' "$TUNNEL_LOG" | head -1 || true)"
  [ -n "$URL" ] && break
  sleep 1
done

if [ -z "$URL" ]; then
  echo "!! Could not obtain a tunnel URL. See $TUNNEL_LOG" >&2
  kill "$SERVE_PID" "$TUNNEL_PID" 2>/dev/null || true
  exit 1
fi

cat <<EOF

============================================================
  VYBIA V2 IS LIVE:

      $URL

  Open this on your iPHONE (or any other computer).
  Do NOT open it in Chrome on this Mac (GPU panic).
  Keep this Mac awake + this script running to keep the URL up.
============================================================
  server pid=$SERVE_PID   tunnel pid=$TUNNEL_PID   log=$TUNNEL_LOG
  Press Ctrl-C to take the site down.

EOF

cleanup() { kill "$SERVE_PID" "$TUNNEL_PID" 2>/dev/null || true; }
trap cleanup INT TERM EXIT
wait "$TUNNEL_PID"
