# Vybia V2 — Sprint S6.1 Report
## Liquid-glass refraction strengthened + glass orb + label overlap fix

**Date:** 2026-06-19
**Base:** S6 (`c989f83`)
**Mode:** full autonomy

---

## TL;DR

The three things the founder flagged on the S6 proof frames are fixed and re-proven
on the iOS simulator (iPhone 17 Pro, iOS 26.3):

- **A — the bubble now reads as unmistakable liquid glass**, not a coloured glow. The
  fragment shader was rewritten with strong magnification + radial lensing + a bright
  glass rim + chromatic aberration. The side-by-side `s6_07_refraction_compare.png`
  shows the foliage clearly *magnified and geometrically bent* under the orb.
- **B — no more "sniper crosshair."** The crosshair was never in the app: it is the
  Flutter **live-test pointer overlay** that `integration_test` paints at each
  `TestGesture` pointer (`_handleRenderViewPaint` in `flutter_test`: a ring + a `+`).
  The real orb is the glass droplet. New proofs are captured under a normal
  `flutter run` (no `TestGesture`), so the frames are crosshair-free.
- **C — top label / title no longer overlap** on reco, mood and profil.

`flutter analyze` clean · `flutter test` 37 passed.

---

## Root-cause finding (important)

The "orb looks like a targeting crosshair" was **a test artifact, not the orb design**.
`IntegrationTestWidgetsFlutterBinding` extends `LiveTestWidgetsFlutterBinding`, which
draws a debug crosshair (circle + vertical + horizontal line, radius
`shortestSide*0.05`) at every active test pointer. The S6 proof frames were captured
*during a held `TestGesture`*, so that overlay sat right on top of the lens and masked
it — which is also why the lens looked "weak" (you were seeing the crosshair, not the
glass). There is no public flag to disable it; `fadePointers` only fades it.

**Decision:** stop proving the held bubble with a `TestGesture` (which forces the
crosshair). Instead drive the orb **programmatically** (no pointer) and screenshot
under a normal `flutter run`. That is exactly what a real user sees — and it let me
actually see and tune the shader.

---

## PART A — shader (`assets/shaders/bubble.frag`)

Rewrote the lens body. Named, tunable constants (raise these if it ever reads flat):

| Constant | Value | Role |
|---|---|---|
| `LENS_AMP` | `1.6` | radial displacement (geometry bend) amplitude |
| `MAG_AMP` | `1.0` | extra magnification toward the centre |
| `CHROMA_PX` | `16.0` | chromatic split at the rim (px) |
| `RIM_BRIGHT` | `0.70` | bright soft glass-rim ring |
| `SPEC_BRIGHT` | `0.50` | upper-left specular kick |
| `INNER_GLOW` | `0.045` | gentle inner luminosity (droplet, not a hollow ring) |

Mechanics: the sample radius collapses toward the centre on a convex droplet curve
(`k = 1 − mag·(1−nd²)`) — non-linear, so straight features bend like a glass bead —
plus an explicit inward displacement (`sin(nd·π)`) that peaks mid-lens. On top: a
bright soft rim ring, curvature darkening just inside it, chromatic per-channel UV
split, an upper-left specular highlight, and a faint inner glow. The shader runs
natively on the sim (verified: `RefractionTechnique.shader`); the painter fallback is
kept for web/CanvasKit.

`SceneScaffold` now feeds `magnification: 0.8` and `lensRadius: 108` (was `0.55` / `84`)
so the bead has real presence.

**Acceptance A:** `s6_07_refraction_compare.png` — same reco image, identical framing,
lens **off** (left) vs **on** (right). The warp is geometric, not a brightness change.

## PART B — orb = glass droplet

With the strengthened shader the held state is a luminous glass droplet (magnified
core + bright rim + specular); the decisive-edge action colour is the orb's inner
glow (`EdgeDecisiveOverlay` additive aura). No reticle, no gunsight lines — those were
only the test overlay (see root-cause).

## PART C — label / title overlap (`EdgeLabels`, `SceneScaffold._TopScrim`)

- The top edge-label is pinned just under the status bar (`top: AppSpacing.xs`,
  centred).
- The top scrim reserves a safe zone above its content (`top: AppSpacing.huge`), so the
  badge and headline always start clearly below the top label.

Verified on reco (`s6_01`), mood (`s6_05`, "Curieux" no longer over "Comment veux-tu te
sentir ?") and profil (`s6_06`).

---

## Re-proof — fresh crosshair-free sim frames (`./screenshots/`)

| File | Scene · state | Proves |
|---|---|---|
| `s6_01_reco_joy.png` | reco · J'aime (left) | gold decisive lens + droplet |
| `s6_02_reco_reject.png` | reco · Pas pour moi (right) | reject desaturate + droplet |
| `s6_03_reco_go.png` | reco · Planifier (down) | green go lens + droplet |
| `s6_04_reco_curious.png` | reco · Plus d'infos (up) | indigo curious lens + droplet |
| `s6_05_mood_bubble.png` | welcome / mood | universal bubble on the mood image |
| `s6_06_profil_bubble.png` | profil | universal bubble on the profil image |
| `s6_07a_rest.png` | reco · lens OFF | the "no-orb" reference |
| `s6_07b_orb.png` | reco · centre, pure lens | the glass droplet, no edge colour |
| `s6_07_refraction_compare.png` | side-by-side | **geometric warp under the orb** |

### How the frames were produced (no OS injection, no crosshair)
- Debug-only auto-drive: `SceneScaffold` (`--dart-define=VYBIA_AUTODRIVE=true`) moves the
  orb programmatically through rest → centre → 4 edges, feeding the same
  `_orb`/`_presence`/aim a finger would (compiled out of release: `const false`).
- A debug-only navigator tour in `app.dart` walks reco → welcome → profil in one run.
- `scripts/s61_tour.sh` runs `flutter run` on the booted sim and snaps each state with
  `xcrun simctl io booted screenshot` (marker-driven; `script -q` pty so markers stream
  unbuffered). `scripts/s61_capture.sh` does a single scene.
- `s6_07_refraction_compare.png` is composited from the rest + centre halves (PIL).

---

## Acceptance
- `flutter analyze` — **clean**.
- `flutter test` — **37 passed** (incl. the idle-no-paint overlay test and the boot test).
- Fresh sim screenshots proving the unmistakable glass refraction + glass droplet +
  fixed labels, all crosshair-free.

## Autonomous decisions
- Diagnosed the crosshair as the Flutter live-test pointer overlay (not the orb) and
  switched the proof method to a programmatic auto-drive under `flutter run` — the only
  way to get a crosshair-free held-bubble frame the founder can open.
- Tuned shader amplitudes empirically against real sim frames until the warp was obvious
  over foliage; left every magnitude as a named constant for future tuning.
- Kept `integration_test/s6_held_test.dart` (gesture mechanics) unchanged; it is no
  longer the proof-frame source because the live binding forces the crosshair.

OSM data + geolocation remain **S7** — not started.
