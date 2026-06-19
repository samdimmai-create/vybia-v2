# Sprint S3 — Intelligent Activity Engine + Immersive Reco Scenes

**Status: PASS** · 2026-06-19 · workspace `~/Desktop/vybia-v2`

The core of Vybia is now live: a deterministic, on-device, explainable
recommendation engine feeding immersive all-orb reco scenes that learn from
revealed preference (J'aime / Pas pour moi) in real time.

## What shipped

| Area | File |
|------|------|
| Activity model (8-axis tags + motive affinity + budget/indoor/geo) | `lib/features/reco/model/activity.dart` |
| Motive taxonomy (hedonic / relaxation / eudaimonic) | `lib/features/reco/model/motive.dart` |
| Recommendation result (+ best-pick flag + "pourquoi" + top dims) | `lib/features/reco/model/recommendation.dart` |
| **Seed catalog — 20 real Montréal activities** | `lib/features/reco/data/activity_catalog.dart` |
| **Engine** (filter → score → rank → best pick → reason) | `lib/features/reco/engine/recommendation_engine.dart` |
| Ambient context (time-of-day / season), test-injectable | `lib/features/reco/engine/reco_context.dart` |
| **Revealed-preference controller** (nudge + anti-repeat + re-rank) | `lib/features/reco/state/reco_controller.dart` |
| Immersive reco scene (all-orb, universal bubble) | `lib/features/reco/screens/reco_screen.dart` |
| "Plus d'infos" full-screen detail overlay | `lib/features/reco/screens/reco_detail_overlay.dart` |
| Planifier stub (S4 placeholder, carries the activity) | `lib/features/reco/screens/plan_stub_screen.dart` |
| Shared 8-axis constant (engine + catalog + nudges agree) | `lib/features/guest/model/activity_axes.dart` |
| Wiring: Intention "Maintenant" → reco; routes `/reco`, `/plan`; `/dev` entry; best-pick badge on `SceneScaffold` | router + intention + scene_scaffold + dev menu |
| Unit tests (11) | `test/recommendation_engine_test.dart` |

## Engine design (deterministic, explainable, no LLM)

`score = 0.42·prefMatch + 0.20·motiveMatch + 0.14·contextFit + 0.09·socialFit
+ 0.10·noveltyBonus − categoryRepeatPenalty`

- **prefMatch** — confidence-weighted similarity over the 8 axes (`weight = 0.2 +
  confidence`, so axes the guest hasn't revealed barely count).
- **motiveMatch** — guest motive weights derived from mood/energy/social/novelty,
  dotted with each activity's motive affinity.
- **contextFit** — time-of-day ("eveningness") match + winter penalty for
  non-winter-friendly outdoors.
- **noveltyBonus** — scaled by the guest's own novelty preference.
- **Feasibility filter** removes splurges for tight budgets and the strict
  indoor/outdoor opposite of a confident preference (with a ≥4 guard so a scene
  is never starved).
- **"Pourquoi ça te va"** generated from the two top-contributing axes.

**Revealed preference:** each J'aime nudges every axis toward the activity
(weight 0.22); each Pas-pour-moi nudges toward its mirror (0.16) and anti-repeats
the item; the list re-ranks immediately so the *next* scene already reflects it.

## Tests — `flutter test` GREEN (19/19; 11 new)

Proven: catalog size/uniqueness/range · engine returns 4–6 with best pick first ·
**different profiles → different top picks** · determinism · non-empty "pourquoi" ·
excludedIds honored · **a Pas-pour-moi removes the pick & re-ranks** · a J'aime
records & advances · likes eventually exhaust · likes nudge the profile toward the
liked axes. `flutter analyze` → **No issues found**. `flutter build web --release`
→ **PASS**.

## Visible test — PASS (web-first / Chrome)

Headless harness wrote openable PNGs to `./screenshots/` (`scripts/shoot_all.sh`,
timeout-hardened, auto-`open`ed): `s3_welcome`, `s3_discover`, `s3_intention`,
`s3_reco`, `s3_plan`, `s3_dev`.

Interactive walk in a real Chrome window (CDP-driven orb drags, captured
in-conversation):
1. `/reco` → best pick **"Atelier de poterie"** + badge "★ Meilleur choix pour
   toi" + pourquoi + universal refraction bubble + orb edge labels.
2. **J'aime** (drag left) → re-rank to **"Musée des beaux-arts"**, pourquoi
   updated live → revealed preference working.
3. **Pas pour moi** (drag right) → re-rank to **"Escalade de bloc"**.
4. **Plus d'infos** (drag up) → full-screen detail overlay with description +
   "Pourquoi pour toi" block + chips + "Touche pour revenir".
5. **Planifier** (drag down) → stub screen carrying the chosen activity.

## Autonomous decisions

- **Simulator vs Chrome:** Xcode *is* present, but a full iOS-simulator build of a
  declared web-first/Chrome app is the slow/risky path and would violate the
  never-block mandate. Used the proven headless-Chrome harness + a real visible
  Chrome window instead. (Booting an iOS sim remains the one optional manual step
  for native previews.)
- **Images:** reused the 8 bundled placeholders, mapped per activity mood/category
  (noted in `assets/CREDITS.md`); dedicated per-activity art is a follow-up. Engine
  + scenes + bubble are fully functional now.
- **Mood handling:** mood is folded into the engine's motive weights rather than
  matched as a 9th axis (it has no activity tag), keeping the match math clean.
- **Detail overlay:** info/detail contract honored (orb disabled, tap-anywhere to
  return). Fixed a loose-Stack sizing bug with `StackFit.expand` so the scrim
  fills the screen (verified post-fix in Chrome).
- **Plan flow:** S4 stub only, per brief; it confirms + parks the choice.

## Known follow-ups (not S3 scope)

- Dedicated per-activity photography.
- S4 real planning flow (date / moment / companions).
- Persisted profile across sessions (S5).
- CDP synthetic drags occasionally flip commit direction in CanvasKit — a test-
  harness quirk only; real pointer/touch input is unaffected.

## Screenshots

`./screenshots/s3_welcome.png` · `s3_discover.png` · `s3_intention.png` ·
`s3_reco.png` · `s3_plan.png` · `s3_dev.png` (all opened). Interactive re-rank /
detail / plan captures shown in-conversation.
