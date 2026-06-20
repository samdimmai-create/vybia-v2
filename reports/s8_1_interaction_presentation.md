# Vybia V2 — Sprint S8.1 — Interaction + Presentation

**Smaller orb · radial edge-wave · fixed returns · bottom description bubble · reflection transition**

Base: S8 (`54c41ef`). Workspace: `~/Desktop/vybia-v2`. Pure Flutter, web-first, iOS-sim
proof. Engine untouched (deferred to S9, per brief).

Commits (one per part):
- `S8.1A: smaller orb (< V1)` — `e9d435a`
- `S8.1B: radial edge-wave filter` — `cf87b2a`
- `S8.1C: returns hardened (double-tap back + hold-to-home)` — `7248249`
- `S8.1D: bottom description bubble + contact reveal` — `94fdd73`
- `S8.1E: reflection transition (exploration + planification)` — `1f98a47`
- `S8.1: interaction + presentation complete` — (final)

---

## PART A — Smaller orb (< V1)

V1 reference: aura ø ~130, core ~110, inner ring ø 80. Target: a total visible footprint
clearly smaller than V1's ~80px ring.

Changes (`scene_scaffold.dart`, `vybia_orb.dart`, `orb_painter.dart`):
- `SceneScaffold.lensRadius` default **60 → 44**. The fallback lens painter draws
  `r ≈ lensRadius` at full contact (`r = radius·(0.64 + 0.36·active)`, active=1 ⇒ r=44),
  so the bubble goes from ~ø120 to **~ø88** — visibly the smallest of the three.
- `VybiaOrb.orbSize` default **88 → 72** (the painted orb on Accueil).
- `OrbPainter` vif re-tune for crispness at small size: outer atmospheric glow
  **1.9× → 1.55×**, orbiting-ring spread **0.32 → 0.26**.

Proof: `screenshots/s8_1_orb_size_compare.png` — old r60 (~ø120) beside new r44 (~ø88) over
the same café image; the new droplet is unmistakably smaller.

## PART B — Radial edge-wave filter

Reworked `EdgeDecisiveOverlay` from a linear edge band into a **radial wave from the contact
point** — the spot on the aimed screen edge the orb heads toward, anchored to the orb's
cross-axis position (`edgeWaveOrigin`).

- Wave painted with `ui.Gradient.radial(origin, radius, [colour@peak, colour@0])`: most
  intense at the contact point, fading with radial distance; the image stays distinct
  everywhere (peak alpha **0.6** tint / **0.5** reject slate; never an opaque flood).
- Intensity **and** coverage scale with proximity: `radius = diag·(0.42 + 0.95·reach)`. Far
  ⇒ a tight halo at the aim point; at full reach the radius passes the screen diagonal, so
  even the opposite corner catches a little colour while staying recognisable.
- Colours unchanged (joy gold / reject grayscale+darken / curious indigo / go green /
  neutral sea-glass). Reject's grayscale `BackdropFilter` is masked by the **same** radial
  wave, so the drain also radiates from the contact point. Paints nothing at idle.
- Exposed `edgeWaveOrigin` / `edgeWaveRadius` (`@visibleForTesting`); **+5 unit tests**
  (origin on the aimed edge, rest mid-point fallback, monotonic coverage-by-proximity,
  diagonal coverage at full reach).

Proof: `s8_1_edge_wave_{joy,reject,curious,go}.png` — the wave blooming from each edge's
contact point across the frame, image still distinct.

## PART C — Returns fixed + device-verified

Root cause of the founder's "not optimal" feel, and the fix (`vybia_orb.dart`):

| Symptom | Root cause | Before → After |
|---|---|---|
| Hold-to-home felt unresponsive | The warning/portal only began after a **fully-silent 3s** immobile wait — no feedback at all for 3 seconds | `holdStill` **3000ms → 1800ms**; `holdGrow` **1000ms → 1300ms** (feedback at 1.8s, deliberate 1.3s portal, ~3.1s total to navigate — still un-accidental) |
| Double-tap-back often missed | The two taps had to land within **26px** on a 3× phone | `_doubleTapSlop` **26 → 44px**, `_doubleTapWindow` **320 → 340ms** |
| Hold cancelled by a resting finger's drift | jitter tolerance too tight | `_holdJitter` **16 → 22px** |

Preserved invariants (already correct, re-verified): release-mid-grow cancels cleanly (no
nav, no commit); movement past threshold cancels the hold and commits the edge normally; a
committed edge is never half of a double-tap; `/accueil` lands with a clean, non-frozen orb
(`_completeHoldHome` → `_reset`).

Tests: **+2** double-tap cases (a slightly-offset double-tap still reads as back; two taps
far apart do not), updated `accueil_hold_home` timings. Device-verified via the S8.1 proof
pass below.

Proof: `s8_1_hold_warning.png` (early warning, portal still tiny), `s8_1_hold_portal.png`
(portal half-open), `s8_1_home_landed.png` (clean Accueil landing), `s8_1_back_from_reco.png`
(the reco scene a double-tap returns from — it pops to the Accueil hub, reco's parent route).

## PART D — Bottom description bubble + contact reveal

Moved the description **off** the open image into a V1-style rounded-rect **glass bubble
pinned near the bottom**, for the image/activity scenes only (reco + the mood/preference
scenes); the structural flows (plan, profil, mes plans) keep the plain top scrim.

- New `_BottomBubble`: badge · title · the "pourquoi" line · an info line · tag chips, with a
  **"touche et décide"** hint below. Blur + scrim are **local to the bubble**, so the rest of
  the hero image stays clear.
- Contact/release model:
  - **REST** — bubble visible; no edge indicators; no orb; HQ image in full.
  - **ON CONTACT** — the bubble fades out (`opacity = 1 − presence`) as the edges + orb fade
    in; the image stays in the background with the orb refraction.
  - **ON RELEASE/CANCEL** — the bubble fades back; edges fade out.
- Reco feeds the bubble: distance + category → the info line ("à 1,4 km · Café"); two vibe
  tags derived from the taste axes ("• posé", "• calme"). `welcome` (mood) + `discover`
  (preference) opt in. New `debugContactProof` / `debugAimProof` pins for capture.
- **+1** widget test (bubble visible at rest, recedes on contact).

Proof: `s8_1_card_rest.png` (bottom bubble visible, no edges), `s8_1_card_contact.png`
(bubble gone, edges + orb on the image).

## PART E — Reflection transition (exploration + planification)

New self-contained `ReflectionTransition` widget: a calm **"Vybia réfléchit"** slideshow that
replays the just-collected preferences before handing off to the result, reused by both
flows.

- Cross-fading mood/category slides, each wearing the universal refraction bubble, on a
  sea-glass wash, with progress dots. **~850ms/slide**, **skippable on touch** (a tap → done)
  so it never fights the ≤ 3-minute target. Empty slides bridge straight through.
- **Exploration**: `RecoScreen` plays it first; slides built from the most confident captured
  dimensions (`exploreReflectionSlides` → image + French leaning, e.g. "Énergie · doux").
  Skipped under the proof/autodrive defines so deterministic captures are clean.
- **Planification**: a new `reflecting` step bridges *companions → confirm* with the activity
  + chosen moment + companions.
- **+8** tests (render / skip / auto-advance-once / empty + explore-slide derivation).

Proof: `s8_1_reflection_explore.png`, `s8_1_reflection_plan.png`.

## PART F — Proof + polish

- `flutter analyze` — **clean** (0 issues).
- `flutter test` — **green** (all prior tests kept; +16 new: B ×5, C ×2, D ×1, E ×8).
- `flutter build web --release` — **OK** (see below).
- Device proof: a single `VYBIA_PROOF81` tour (`lib/features/dev/s8_1_proof_tour.dart`) +
  `tool/capture_s8_1.sh` captures every frame crosshair-free on the booted iPhone 17 Pro
  (iOS 26.3) via marker-synced `xcrun simctl io booted screenshot`. One sim build covers all
  parts (efficiency: no per-part rebuild).

### Decisions
- Bottom bubble applied to **reco + welcome (mood) + discover (preference)**; `intention` is
  left on the top scrim (it's an intention/routing choice whose question should stay legible),
  consistent with the brief excluding the structural flows.
- Edge-wave origin anchored to the **edge × orb cross-axis**, not the orb itself, so colour
  reads as flowing *in from* the chosen edge.
- Hold-to-home shortened rather than adding a separate pre-warning indicator — fewer moving
  parts, same outcome (feedback sooner), near the MVP target.

### Proof — captured + visually verified

One `VYBIA_PROOF81` sim run on the booted **iPhone 17 Pro (iOS 26.3)** produced all 13 frames
in `screenshots/`, each inspected (no fake PASS):

| Frame | Verified |
|---|---|
| `s8_1_orb_size_compare.png` | new r44 bubble visibly smaller than the old r60 |
| `s8_1_card_rest.png` | bottom glass bubble (badge/title/info/tags/hint), no edges, no orb |
| `s8_1_card_contact.png` | bubble gone, 4 edge labels + small orb on the image |
| `s8_1_edge_wave_{joy,reject,curious,go}.png` | colour wave blooming from each edge's contact point, image still distinct (reject drains+darkens from the right) |
| `s8_1_reflection_explore.png` | "Vybia réfléchit…" + "Énergie · doux" + dots + skip hint |
| `s8_1_reflection_plan.png` | "Vybia prépare ton plan…" plan slideshow |
| `s8_1_hold_warning.png` | early warning hint, portal still tiny |
| `s8_1_hold_portal.png` | calm portal expanded over the frame (distinct from warning) |
| `s8_1_home_landed.png` | clean Accueil hub, non-frozen small orb |
| `s8_1_back_from_reco.png` | the reco scene a double-tap returns from (lands on Accueil) |

Result: **build web release OK · analyze clean · 72 tests green · all proof frames verified**.

### New / changed constants
- `lensRadius` 44 · `orbSize` 72 · glow 1.55× · ring 0.26×.
- edge-wave: peak 0.6 tint / 0.5 reject; desat mask 0.92; `radius = diag·(0.42 + 0.95·reach)`.
- hold: `holdStill` 1800ms · `holdGrow` 1300ms · `_holdJitter` 22 · `_doubleTapSlop` 44 ·
  `_doubleTapWindow` 340ms.
- reflection: ~850ms/slide, ≤3 explore slides, skippable.
