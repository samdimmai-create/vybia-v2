#!/usr/bin/env bash
#
# S6.2 — A/B the bubble. Runs the app's programmatic proof tour
# (VYBIA_AUTODRIVE → reco → welcome → profil via the navigator, no pointer →
# no Flutter live-test crosshair) for ONE lens variant and snaps the 'centre'
# state (the pure glass droplet, no edge colour) of the reco scene and the
# welcome (mood) scene with `xcrun simctl io booted screenshot`.
#
# The centre frame is captured on its SECOND appearance per scene so the
# backdrop image is fully decoded (first cycle = warmup).
#
# Usage: scripts/s62_ab.sh <sim-udid> <vif|calm>
#   → screenshots/s6_2_<lens>_reco.png and screenshots/s6_2_<lens>_mood.png
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${1:?usage: s62_ab.sh <sim-udid> <vif|calm>}"
LENS="${2:?usage: s62_ab.sh <sim-udid> <vif|calm>}"
OUT="$ROOT/screenshots"
mkdir -p "$OUT"

cleanup() { pkill -f "flutter_tools.*run" 2>/dev/null; pkill -f "flutter run" 2>/dev/null; }
trap cleanup EXIT

echo "[s62] flutter run (autodrive tour, lens=$LENS) on $SIM …"
cd "$ROOT"

script -q /dev/null flutter run -d "$SIM" \
  --dart-define=VYBIA_AUTODRIVE=true \
  --dart-define=VYBIA_LENS="$LENS" 2>&1 | (
  scene=""
  centre_seen=0     # times 'centre' seen in the current scene
  captured=" "      # scene names already shot
  ncap=0            # how many wanted scenes shot
  while IFS= read -r line; do
    echo "$line"
    case "$line" in
      *VYBIA_SCENE\ *)
        scene="$(printf '%s' "$line" | sed -n 's/.*VYBIA_SCENE \([a-z-]*\).*/\1/p')"
        centre_seen=0
        echo "[s62] >>> scene: $scene"
        ;;
      *VYBIA_DRIVE\ centre*)
        [ -n "$scene" ] || continue
        # only the reco and welcome (mood) scenes are wanted
        case "$scene" in reco|welcome) : ;; *) continue ;; esac
        centre_seen=$((centre_seen + 1))
        [ "$centre_seen" -lt 2 ] && continue   # skip first cycle (decode warmup)
        case "$captured" in *" $scene "*) continue ;; esac
        captured="$captured$scene "
        ncap=$((ncap + 1))
        suffix="reco"; [ "$scene" = "welcome" ] && suffix="mood"
        ( sleep 2.5
          xcrun simctl io booted screenshot "$OUT/s6_2_${LENS}_${suffix}.png" >/dev/null 2>&1 \
            && echo "[s62]   OK s6_2_${LENS}_${suffix}.png" \
            || echo "[s62]   FAIL s6_2_${LENS}_${suffix}.png" ) &
        if [ "$ncap" -ge 2 ]; then
          sleep 3.5
          echo "[s62] both centre frames captured for lens=$LENS"
          break
        fi
        ;;
    esac
  done
  wait
)
echo "[s62] done (lens=$LENS)."
