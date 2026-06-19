# Vybia V2 — Sprint S0 (Foundations) — Report

**Date:** 2026-06-19 · **App:** `vybia_v2` (pure Flutter, web-first) · **Commit:** `1de73e0`

## PASS / FAIL checklist

| # | Item | Result | Evidence |
|---|------|--------|----------|
| 1 | App builds (`flutter build web --release`) | ✅ PASS | harness step builds before every screenshot |
| 2 | `flutter analyze` clean | ✅ PASS | `No issues found!` |
| 3 | Widget test (orb born + commits direction) | ✅ PASS | `flutter test` → `All tests passed!` |
| 4 | Chrome is a web device | ✅ PASS | `flutter devices` → `Chrome (web)`; doctor web ✓ |
| 5 | Theme applied (sea-glass, google_fonts, no empty families) | ✅ PASS | screenshot: Fraunces wordmark + sea-glass field |
| 6 | Orb renders | ✅ PASS | `/tmp/vybia_v2/s0_orb_preview.png` |
| 7 | Orb reacts (born → follows → commits → resets) | ✅ PASS | widget test drag-right commits a direction |
| 8 | Screenshot captured | ✅ PASS | `/tmp/vybia_v2/s0_orb_demo.png` |
| 9 | Git committed | ✅ PASS | `1de73e0 S0: foundations, design system, orb` |

**Environment note:** Android/iOS doctor categories fail — irrelevant for web-first.
Web toolchain is fully green.

## Screenshots
- Demo (orb host + edge labels): `/tmp/vybia_v2/s0_orb_demo.png`
- Orb living look: `/tmp/vybia_v2/s0_orb_preview.png`

## Structure
```
lib/
  main.dart                      app bootstrap (tiny)
  app.dart                       MaterialApp (theme + router)
  core/theme/                    app_colors, app_spacing, app_theme
  core/router/                   app_router
  components/orb/                vybia_orb (Listener), orb_painter
  features/demo/                 orb_demo_screen, orb_preview_screen
  shared/                        edge_labels
scripts/visual_test.sh           headless-Chrome screenshot harness
```

## Harness note (for future sprints)
Headless Chrome clamps its window to a ~500px min logical width, so a true 430px
viewport is unreachable headless; `visual_test.sh` uses 500×1084 @2× so the
capture width matches Flutter's layout width (prevents right-edge clipping).
