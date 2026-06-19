# Vybia V2 — Sprint S2 Report

**Result: PASS** (autonomous, end-to-end). Guest loop (all-orb, French) + refined
water/ice/glass orb-bubble, verified live in a visible Chrome window and via the
headless screenshot harness.

## Part A — Orb & bubble refinement

1. **Smaller orb** — `VybiaOrb.orbSize` 132 → 88; refraction lens default radius
   96 → 84.
2. **Water + ice + glass lens** (`_LensPainter`, web-safe painter path) — rewritten
   from a flat uniform magnifier into:
   - **True non-uniform radial refraction**: the image is resampled in 14
     concentric annuli whose zoom rises toward the centre on a convex droplet
     curve (centre bulges, rim compresses) — genuine barrel refraction, not a
     single scale.
   - **Frosted icy rim** (blurred bright inner band), **layered glass speculars**
     (soft upper-left shine + sharp wet hotspot + curved upper-rim glare),
     **subtle chromatic dispersion** (red/blue split at the rim via offset
     additive passes), curvature vignette, sea-glass + crisp double rim light.
3. **Born-on-contact / gone-on-release** — `VybiaOrb` now streams a `presence`
   value (0→1 fade+scale-in ~150ms on pointer-down via an `_appear` controller,
   1→0 progressive dissolve ~150ms on release/cancel). The lens multiplies its
   strength by presence, so it intensifies on touch and recedes on release —
   quick but smooth, never an instant pop, never frozen (state still resets on
   both pointer-up AND pointer-cancel).
4. **Higher-res images** — all 8 bundled assets re-fetched at 1280×1600 (credits
   updated in `assets/CREDITS.md`).

Web still uses the painter lens (shaders load but `AnimatedSampler` doesn't
visibly apply on CanvasKit — the documented V1/S1 lesson); the GLSL shader is
kept for a future native shell.

## Part B — Guest loop (all-orb, French)

- **Splash** (`/`) → brief liquid-orb moment, auto-continues to Welcome (1.7s).
- **Welcome** (`/welcome`) → "Comment veux-tu te sentir ?" — guest entry, no
  account. The four orb directions are four moods (Posé / Curieux / Sociable /
  Plein d'énergie), each seeding the engine with correlated priors.
- **Discover** (`/discover`) → adaptive preference + mood capture. The
  **`AdaptiveEngine`** (deterministic, on-device, no LLM) picks the *least-certain*
  dimension among {energy, social, novelty, distance, indoor/outdoor, timing,
  budget, vibe}, answered by moving the orb. Correlated *nudges* spread
  confidence, so it **stops early** (3–4 swipes typical, hard cap 6) instead of
  forcing all eight.
- **Intention** (`/intention`) → "Maintenant ou planifier ?" via the orb.
- **Profil prêt** (`/profil-pret`) → recap of what the engine learned (proof the
  questions shaped a real profile) + chosen intention + Recommencer.
- **Hidden `/dev`** → jump straight to any screen (resets the session first) so
  visual tests are never blocked by flow order.

State lives in a single `GuestController` (`ChangeNotifier`) shared across routes
via `GuestScope` (`InheritedNotifier`) mounted above the navigator.

### Architecture (modular, one responsibility per file)

```
lib/features/guest/
  model/      dimension.dart · guest_profile.dart · question.dart
  data/       assets.dart · question_bank.dart
  engine/     adaptive_engine.dart
  state/      guest_controller.dart  (+ GuestScope)
  widgets/    scene_scaffold.dart    (universal full-bleed image + bubble + orb)
  screens/    splash · welcome · discover · intention · profile_ready
lib/features/dev/dev_menu_screen.dart
```

## Verification

- `flutter analyze` → **No issues found.**
- `flutter test` → **8/8 pass** (5 adaptive-engine unit tests + boot + 2 bubble).
- `flutter build web --release` → **✓ Built build/web.**
- **LIVE visible-Chrome walkthrough** (authoritative): Welcome → 4 adaptive
  questions → Intention → populated "Profil prêt". Confirmed the engine is
  genuinely adaptive (after choosing "Plein d'énergie" it *skipped* energy and
  asked the least-certain dimension next) and the orb commits via real drags.
- **Headless screenshots** in `./screenshots/` (opened for review):
  `s2_bubble_refined.png`, `s2_welcome.png`, `s2_discover.png`,
  `s2_intention.png`, `s2_profile_ready.png`, `s2_dev.png`.

## Autonomous decisions (no questions asked, per brief)

- **Routing fix (key):** Flutter's default initial-route handling built a
  `[splash, target]` stack; the splash's auto-advance `pushReplacement` clobbered
  the deep-linked top route, so every `/#/route` wrongly landed on Welcome. Fixed
  with `onGenerateInitialRoutes` returning a **single** route for the deep link.
  This is what makes `/dev` and per-route visual tests actually work.
- **Engine tuning:** `confidenceThreshold` 0.6, answer +0.7 confidence, nudge
  weight 0.3 (~+0.18), early-stop at `confidentTarget` 5 / `maxAsked` 6 /
  `minAsked` 3.
- **Welcome = mood capture** (folded the first dimension into the entry screen
  rather than adding a separate step) to keep cognitive load low.
- **Ambient bubble floor (0.5)** on guest scenes so every image *always* wears
  the bubble (brand non-negotiable + headless-screenshot-able), lifted to full on
  contact.
- **Test harness hardened** (`scripts/shoot_all.sh`): server in background, 20s
  readiness wait, per-shot bash watchdog (macOS has no `timeout`), always reaps
  the server, self-terminates ~90s even on failure. Never blocks.

## Known / deferred

- Headless `/profil-pret` shows an empty recap (fresh load, no answers); the
  populated recap is proven in the live walkthrough.
- Real persistence (profile survives reload) is S5.
- Recommendations themselves (consuming the profile) are a later sprint.
