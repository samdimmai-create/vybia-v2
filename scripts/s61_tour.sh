#!/usr/bin/env bash
#
# S6.1 — single-run visual proof tour. Drives the app (VYBIA_AUTODRIVE) through
# reco → welcome → profil via the in-app navigator (no pointer → no Flutter
# live-test crosshair) and captures each scene's driven states with
# `xcrun simctl io booted screenshot`. The app prints `VYBIA_SCENE <name>` on
# each hop and `VYBIA_DRIVE <state>` on each orb state.
#
# Usage: scripts/s61_tour.sh <sim-udid>
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?usage: s61_tour.sh <sim-udid>}"
OUT="$ROOT/screenshots"
mkdir -p "$OUT"

cleanup() { pkill -f "flutter_tools.*run" 2>/dev/null; pkill -f "flutter run" 2>/dev/null; }
trap cleanup EXIT

echo "[tour] flutter run (autodrive tour) on $SIM …"
cd "$ROOT"

script -q /dev/null flutter run -d "$SIM" --dart-define=VYBIA_AUTODRIVE=true 2>&1 | (
  scene=""
  captured=" "      # "scene:state" pairs already shot
  scene_count=0     # markers seen in the current scene (for warmup skip)
  scenes_done=" "
  while IFS= read -r line; do
    echo "$line"
    case "$line" in
      *VYBIA_SCENE\ *)
        scene="$(printf '%s' "$line" | sed -n 's/.*VYBIA_SCENE \([a-z-]*\).*/\1/p')"
        scene_count=0
        echo "[tour] >>> scene: $scene"
        ;;
      *VYBIA_DRIVE\ *)
        [ -n "$scene" ] || continue
        name="$(printf '%s' "$line" | sed -n 's/.*VYBIA_DRIVE \([a-z]*\).*/\1/p')"
        [ -n "$name" ] || continue
        scene_count=$((scene_count + 1))
        # Skip only the first state per scene (image decode warmup).
        [ "$scene_count" -le 1 ] && continue
        key="${scene}:${name}"
        case "$captured" in
          *" $key "*) : ;;
          *)
            captured="$captured$key "
            ( sleep 2.5
              xcrun simctl io booted screenshot "$OUT/drive_${scene}_${name}.png" >/dev/null 2>&1 \
                && echo "[tour]   OK drive_${scene}_${name}.png" \
                || echo "[tour]   FAIL ${key}" ) &
            ;;
        esac
        # Mark a scene done once its 6 states are shot; stop after profil.
        n=$(printf '%s' "$captured" | tr ' ' '\n' | grep -c "^${scene}:" 2>/dev/null || echo 0)
        if [ "$n" -ge 6 ]; then
          case "$scenes_done" in *" $scene "*) : ;; *) scenes_done="$scenes_done$scene " ;; esac
        fi
        if [ "$scene" = "profil" ] && [ "$n" -ge 6 ]; then
          sleep 3
          echo "[tour] all scenes captured"
          break
        fi
        ;;
    esac
  done
  wait
)
echo "[tour] done."
