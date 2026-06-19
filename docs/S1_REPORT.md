# Vybia V2 — Sprint S1 — Universal bubble-over-image refraction

**Date:** 2026-06-19 · **App:** `vybia_v2` (pure Flutter, web-first)

## Goal
Prove the signature *before* building the rest: a **reusable** widget that takes
any image and, where the orb passes over it, **refracts** the image like a
liquid-glass bubble (iOS-lockscreen look) — lens magnification + radial
refraction + chromatic rim + specular highlight. Reusable for emotions,
recommendation scenes, and any image card.

## What shipped
| Piece | File |
|-------|------|
| GLSL refraction shader (magnify + refract + chromatic fringe + highlight + sea-glass rim) | `assets/shaders/bubble.frag` |
| **Reusable** live bubble widget (shader path + painter fallback, reports active technique) | `lib/components/bubble/refraction_bubble.dart` |
| Painter-lens fallback (magnification + chromatic ring + highlight, web-safe) | (same file, `_LensPainter`) |
| Orb wiring: live position stream + hide painted body so the bubble *is* the orb | `lib/components/orb/vybia_orb.dart` (`onPositionChanged`, `showOrb`) |
| Demo: full-bleed image + orb-driven lens, idle drift, swipe to cycle images | `lib/features/demo/refraction_demo_screen.dart` (route `/bubble`) |
| Static card variant of the bubble (reusable for reco/emotion cards) | `lib/components/bubble/bubble_image.dart` |
| 3 bundled real images + attribution | `assets/images/recos/*`, `assets/CREDITS.md` |
| Harness now writes to project `./screenshots/` and `open`s the proof | `scripts/visual_test.sh` |

## Which technique works (shaders vs fallback)
- The GLSL shader **compiles and loads** on web/CanvasKit (the demo's on-screen
  label initially read `Rendu : shader GLSL`).
- **But `AnimatedSampler` does not visibly apply the shader on this CanvasKit
  web build** — the first screenshot showed the image with *no* lens. This is
  the documented web/CanvasKit runtime-shader limitation the brief warned about.
- **Decision (autonomous):** on web (`kIsWeb`) we use the painter-based lens
  fallback, which genuinely magnifies/refracts and is guaranteed at 60fps. The
  shader path is retained for native builds (`!kIsWeb`). The component reports
  the live technique via `onTechnique`, surfaced on-screen as
  `Rendu : lentille (fallback)`.
- Result: the refraction is **always visible**, never blocked by shader support.

## VISIBLE TEST — proof (refraction screenshots, opened)
1. `screenshots/s1_refraction.png` — headless mobile-framed capture, route
   `/bubble`: the liquid-glass bubble refracting the fjord (magnified content,
   specular highlight, sea-glass rim). **Opened automatically by the harness.**
2. `screenshots/s1_refraction_visible.png` — a **real visible Chrome window**
   (URL bar `localhost:8099/#/bubble`) showing the bubble magnifying a canal
   building on the *second* image after a swipe — proving the effect is
   **universal across images** and that swipe-cycling works.

Live window: a release build is served on `http://localhost:8099/#/bubble` and a
visible Chrome window is open there — drag anywhere to move the lens; swipe
left/right (orb commit) to cycle images.

## Checklist
| # | Item | Result |
|---|------|--------|
| 1 | 3 real images bundled + declared + credited | ✅ `assets/images/recos/`, `CREDITS.md` |
| 2 | `bubble.frag` GLSL written + declared under `flutter: shaders:` | ✅ |
| 3 | Reusable `RefractionBubble` (image + orb position → refracted) wired to `VybiaOrb` | ✅ |
| 4 | Demo: full-bleed image + draggable orb, live refraction | ✅ route `/bubble` |
| 5 | Visible Chrome + refraction screenshot in `./screenshots`, opened | ✅ (both PNGs) |
| 6 | Shader-fail fallback implemented + technique stated | ✅ web→painter lens, native→shader |
| 7 | `flutter analyze` clean | ✅ `No issues found!` |
| 8 | `flutter test` | ✅ `All tests passed!` (3 tests) |
| 9 | `flutter build web --release` | ✅ |

## Notes / next
- True per-pixel shader refraction is only proven to *load* on web, not render.
  If we later move off CanvasKit (Wasm/Skwasm or a native shell) the shader path
  should light up automatically — no API change needed.
- The fallback lens approximates radial displacement via uniform magnification +
  a chromatic ring; a future pass could add barrel displacement in the painter.
