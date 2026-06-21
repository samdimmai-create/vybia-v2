#!/usr/bin/env bash
# S12 — run/build Vybia V2 with the keyed providers, secrets-safe.
#
# Keys are read from `tool/secrets.env` (gitignored) and passed ONLY via
# --dart-define. They never touch source or git. Any missing key is simply
# omitted → that provider degrades gracefully. Open-Meteo (weather) is keyless.
#
#   ./tool/run_with_keys.sh         # flutter run -d chrome
#   ./tool/run_with_keys.sh build   # flutter build web --release
set -euo pipefail
cd "$(dirname "$0")/.."

ENV_FILE="tool/secrets.env"
DEFINES=()
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi
for k in GEOAPIFY_KEY FOURSQUARE_KEY TMDB_KEY TICKETMASTER_KEY; do
  v="${!k:-}"
  if [[ -n "$v" ]]; then DEFINES+=("--dart-define=$k=$v"); fi
done

echo "[run_with_keys] ${#DEFINES[@]} key(s) wired (values hidden)."
if [[ "${1:-run}" == "build" ]]; then
  exec flutter build web --release "${DEFINES[@]}"
else
  exec flutter run -d chrome "${DEFINES[@]}"
fi
