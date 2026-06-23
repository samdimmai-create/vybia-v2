# Sprint S17 — ORBE · THÈME · EFFETS (langage visuel signature)

**Theme held throughout:** *apaisant électrique* — eau / glace / orbe / transparent /
doux / vibrant / confortable, jamais agressif. Palette A (*Aurore glacée*) kept.

**Machine-safe:** no local flutter run/build/iOS-sim/Chrome on this Mac. Verified
with `flutter analyze` (0 issues) + `flutter test` (**218 passing**) and shipped to
the cloud builder via `./tool/deploy.sh`. Visual confirmation is on the founder's
iPhone (GitHub Pages URL printed by the deploy).

One commit per part (A–E).

---

## Part A — Signature water transition (splash ⇄ return-to-home) · `S17A`

A single reusable widget — `lib/shared/water_transition.dart` → **`WaterReveal`** —
now powers BOTH moments, so launch and return read as the same brand gesture:

- A bubble of the calm sea-glass `CalmHomeField` (water/ice/glass) **grows from a
  centre point** and progressively **submerges** whatever is beneath it (going
  underwater), driven purely by a `progress` 0→1 (the caller owns timing).
- A **blurred chromatic wavefront** rides the growing boundary (pearl crest + a
  cyan/champagne refractive split) and fades out as the water fills the screen.
- A faint **aqua submersion veil** inside the disc deepens with progress.

Wiring:
- **Splash** (`splash_screen.dart`): plays it forward — water surfaces out of the
  breathing orb to fill the screen — keeping the "Vybia" wordmark and the existing
  ~1.7 s auto-nav (first-visit → Welcome, returning → Accueil).
- **Return-to-home** (`scene_scaffold.dart`): the hold-to-home portal now *is* a
  `WaterReveal` (replacing the old inline `ClipPath`+`CalmHomeField`), grown by the
  orb's hold progress. At `progress→1` it covers the screen → Accueil.

**Constants:** swell easing `easeInOutCubic`; `seedRadius` = orb size (scene
`lensRadius` 44, splash 66); cover radius ×1.04 (corners reached cleanly); veil
`primary @ 0.10·eased`.

## Part B — Orb feel (alive / natural / comfortable / electric-calm) · `S17B`

`orb_painter.dart` tuned; size unchanged (still the small V1 jewel), 1:1 tracking
untouched:
- **Two-frequency breath** `1.0 + 0.038·sin(φ) + 0.012·sin(2.7φ+0.8)` — alive, not
  metronomic, still gentle.
- **Drifting caustic specular** orbiting on a tiny Lissajous so light plays across
  the glass like a living droplet (soft, never glittery).
- **Softened rings** (peak opacity 0.5→0.42, slimmer stroke, 0.6 blur) — calm
  ripples, not hard wire rings.
- **Faint cyan refractive rim** selling the liquid-glass sea-glass family.

## Part C — Edge precision: commit near the edge; effect proximity-gated · `S17C`

The decisive model is reframed around **proximity to the screen edge**, not distance
from the gesture origin (`vybia_orb.dart` + `orb_painter.dart`):

- New pure **`edgeProximityReach(bounds, dir, pos)`**: `0` in the centre band → `1`
  at the edge; band depth = `shortestSide × kEdgeZoneFrac`.
- The orb's live `reach` (drives the decisive image filter + the orb aura) is now
  this proximity, so the filter/coloration are **OFF mid-scene and bloom only on
  approach** to an edge.
- **`_commitDirection()`**: a release commits only with a deliberate directional
  intent **AND** the orb close enough to that edge. A long drag that ends mid-scene
  **dissolves** instead of committing. (Legacy origin-distance threshold kept only
  as a pre-layout fallback. Throw-arrival already commits at the edge.)
- `OrbPainter` directional coloration is proximity-gated (neutral accent at reach 0,
  leaning to the edge colour on approach).

**Tunable knobs:** `kEdgeZoneFrac = 0.42`, `kEdgeCommitReach = 0.5`,
`kEdgeIntentMin = 32 px`.

## Part D — Corners = gradient of the two nearby edges (dominant wins) · `S17D`

Near a corner the effect is a **gradient of the two nearby edges' colours**, while
the committed choice stays the **dominant** edge:

- `OrbAim` gains an optional `secondary` edge + `blend` (0 cardinal → 0.5 even
  corner). Pure **`perpendicularEdge()`** (minor axis ≥ `minorFrac` 0.18 of major)
  and **`cornerBlend()`** (`share × diagRatio`, clamped 0..0.5 so the closer edge
  always keeps the majority) compute them.
- `OrbPainter` and `EdgeDecisiveOverlay` lerp the dominant edge colour toward the
  secondary's by `blend` (skipped for reject / unlabelled / dead edges). The wave
  still **originates on the dominant edge** and the commit is unchanged.
- `SceneScaffold` resolves + passes the secondary action.

## Part E — Polish + deploy · `S17`

- Cross-checked all `SceneScaffold` scenes (welcome/discover/intention/reco/plan/
  profil) inherit the new model with no per-scene changes; demos/proof tours use
  the new optional params via defaults.
- `flutter analyze`: **0 issues.** `flutter test`: **218 passing**, incl. the new
  `test/edge_precision_test.dart` (proximity ramp, near-edge commit gating,
  proximity-gated reach, `perpendicularEdge`, `cornerBlend`, diagonal-into-corner
  commits the dominant edge).
- Deployed via `./tool/deploy.sh` (cloud build → GitHub Pages).

### For the founder — what to look for on the iPhone
- **Splash & return share the water effect:** the app surfaces from rising water on
  launch, and holding to go home grows the *same* water out of the orb to submerge
  the scene before arriving on the calm Accueil.
- **Edge filter only kicks in near an edge:** at the centre the photo is clean; the
  decisive colour/drain intensifies as you carry the orb toward an edge, and a
  release that isn't close enough just dissolves (no choice made).
- **Corners blend two colours:** aim into a corner and the tint is a gradient of the
  two edges — but the choice you commit is the edge you're most aligned with.
