# Vybia V2 — Sprint S6 Report
## Signature bubble/edge proven on the iOS simulator + polish

**Date:** 2026-06-19
**Base:** S5 (`e115873`)
**Mode:** full autonomy

---

## PART A — live held-orb refraction + decisive edge, PROVEN on the iOS simulator

This closes V1 failure #1 (the bubble effect was never actually delivered / proven on a
real device frame — only via the static `/edge-demo` route).

### What was proven
Six real iOS-simulator device frames (status bar / notch visible), each captured with
`xcrun simctl io booted screenshot` **while the orb is held at a decisive edge** — so the
native refraction shader + the decisive-edge colour are rendering live in a gesture, not a
static mockup:

| File | Scene · edge | Proves |
|---|---|---|
| `s6_01_reco_joy.png` | reco · left (J'aime) | gold orb + gold-tinted refraction lens |
| `s6_02_reco_reject.png` | reco · right (Pas pour moi) | orb held right, reject filter |
| `s6_03_reco_go.png` | reco · down (Planifier) | green **go** lens + orb crosshair |
| `s6_04_reco_curious.png` | reco · up (Plus d'infos) | indigo **curious** lens |
| `s6_05_mood_bubble.png` | mood/emotions image | universal bubble on a mood image |
| `s6_06_profil_bubble.png` | /profil image | universal bubble on the profil image |

Universal across **reco (4 edges) + mood + profil** images → the bubble/edge treatment is
the same everywhere.

### Exact gesture-driving approach (no OS injection)
- `integration_test/s6_held_test.dart` runs on the booted sim via
  `flutter test integration_test/s6_held_test.dart -d <udid>`. The app is visibly rendered
  on the simulator during the test.
- The held gesture is driven at the **Flutter framework level** with a `TestGesture`:
  `startGesture(center)` → `moveTo(centre + edgeOffset)` → **no release** → pump real-time
  frames so the orb sits held at the edge (commit only fires on pointer-up, so a hold shows
  the live filter without navigating). No CGEvent / osascript / cursor injection.
- Capture is **marker-driven** (`scripts/s6_capture.sh`): the test prints `VYBIA_SHOT <name>`
  at each held state; the script snaps `xcrun simctl io booted screenshot` ~2.8 s into the
  ~6.6 s hold. App/simulator-targeted capture only.

### Honest notes / limitations
- The decisive-edge **colour + refraction lens render natively on the sim** (clearly visible
  on go / curious / mood). The refraction *deformation* is most legible where the underlying
  image has structure; over large uniform foliage it reads more as a coloured lens than a
  strong warp — but the shader is genuinely running on-device (not a flat tint).
- First attempt: the very first capture (`s6_01` joy) missed the orb due to a first-gesture
  timing race. Hardened the timing (settle the lens before the marker, longer hold, capture
  at +2.8 s) and **re-ran** — all six frames then show the held orb at the correct edge.
- iOS build cost: first build ~352 s; the incremental re-run ~105 s (within a capped budget,
  no fallback needed). The S5 destination blocker (Xcode 26.3 / `iphonesimulator26.2`) is
  resolved now that the iOS 26.3.1 runtime is installed and an iPhone 17 Pro is booted.

---

## PART B — polish (tight, no new features)

A polish audit found most items already done in S1–S5; changes + verifications:

**Changed**
- `SceneScaffold` headline + prompt now have `maxLines` + `TextOverflow.ellipsis` — overflow
  safety for long activity titles / prompts on every orb scene.

**Verified already-correct (no change needed)**
- Edge labels **centered on each screen edge** (never corners), pinned with explicit insets
  (`EdgeLabels`). Explicit fonts inherited from the themed `google_fonts` default.
- Decisive-edge **colour per action meaning** on the held-orb filter (joy/reject/go/curious),
  proven by PART A. *Decision:* edge **labels** keep their fixed per-direction (spatial)
  colours rather than action colours — colouring the "Supprimer"/reject label by reject's
  near-black slate would make it unreadable. The action colour is carried by the live filter.
- Orb state machine resets on **pointer-up AND pointer-cancel** (`VybiaOrb`); no frozen /
  stuck / re-activating orb; info/detail panels are tap-to-dismiss, not orb-driven.
- Graceful **empty state** for Mes Plans (icon + guidance copy); readable Détails panel
  (scrollable, tap-to-return); selected-plan layer has a discoverable close affordance.
- The decisive-edge overlay **paints nothing when idle** (returns `SizedBox.shrink`), now
  covered by a test.

---

## Acceptance

- `flutter analyze` — **clean**.
- `flutter test` — **37 passed** (all S1–S5 + new `test/edge_decisive_test.dart`: the
  held-orb edge overlay fires for real edges and paints nothing idle, incl. the reject
  desaturate path).
- iOS-simulator screenshots in `./screenshots/` (`s6_01…s6_06`) proving the live held-orb
  refraction + edge colour on reco ×4 edges, mood, and profil. **No Chrome fallback used** —
  the on-device shader proof is complete.

## Autonomous decisions
- Marker-driven `simctl` capture (vs `flutter drive` `takeScreenshot`) to honour
  "capture with `xcrun simctl io booted screenshot` only".
- Re-ran (cheap incremental build) instead of accepting a missed joy frame.
- Kept spatial edge-label colours for readability; documented the rationale.

Real OSM data + geolocation remain **S7** — not started.
