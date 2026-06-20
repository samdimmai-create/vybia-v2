# S9.2 — Transparent info bubble (image stays the hero)

**Goal:** the bottom description must no longer cover the hero image. Drop the
opaque frosted card; keep the text legible by its own means; behaviour unchanged
(visible at rest, gone on contact, back on release). One commit. Chrome proof,
no simulator.

## What was removed

In `_BottomBubble` (`lib/features/guest/widgets/scene_scaffold.dart`):

- The `ClipRRect` + `BackdropFilter(blur 16/16)` that frosted the photo behind
  the description.
- The solid card `Container` (`AppColors.surface @ 0.46` fill + pearl border +
  rounded corners) that boxed the text.
- The now-unused `import 'dart:ui' as ui;` (only the blur used it).

The image now shows through **fully** behind the floating text — V1
"Columbus Café & Co" style.

## Legibility technique (no opaque background)

- **Text shadow / outer glow only:** new `_kBubbleTextShadow` — a tight
  `black, blur 4` glyph-hugging shadow plus a wider `black87, blur 14` lift —
  applied to title, "pourquoi" line, info line, tag-chip text and the
  "touche et décide" hint.
- **Weight + colour bumped** for contrast on busy photos: title/info/subtitle
  to `w700`; subtitle and hint moved off the dim `textSecondary`/`textMuted`
  greys onto pearl (with the shadow doing the contrast work).
- **At most a very faint bottom-anchored gradient veil:** the description's own
  `Container` carries a `transparent → AppColors.bg @ 0.30` vertical gradient
  (top of the text → very bottom only). No solid card, no blur — just enough
  floor under the smallest text on bright images. The image remains the hero.
- Badge and tag **pills** were kept (they are V1-style content chips, not the
  removed card); tag pill fill softened (`0.7 → 0.55`) so it reads as a chip,
  not a panel.

## Behaviour (unchanged)

The description's `opacity` is still driven by the scene: full at rest, fading
to 0 as the orb is born on contact, back on release/cancel. Only the
image/activity scenes (`bottomBubble: true`: reco + mood/preference) are
affected; structural scenes (plan, profil, mes plans) keep their `_TopScrim`.

## Verification

- `flutter analyze` — **No issues found.**
- `flutter test` — **112 passing.** The S8.1D bottom-bubble test gained a
  `expect(find.byType(BackdropFilter), findsNothing)` assertion at rest,
  locking in the transparency (no frosting); the recede-on-contact assertions
  are untouched.
- `flutter build web --release` — **OK** (built with `VYBIA_PROOF92=true`).
- Chrome proof (visible local window via `tool/web_shoot.sh` +
  `tool/cdp_capture.mjs`, page-targeted DevTools screenshots, no simulator):
  - `screenshots/s9_2_bubble_transparent.png` — at rest: badge · title ·
    pourquoi · info line · tag chips · hint all readable, the café brick wall
    fully visible behind them, no frosted panel.
  - `screenshots/s9_2_bubble_contact.png` — on contact: description gone, the
    glass orb at centre + the four decisive edges (J'aime / Pas pour moi /
    Plus d'infos / Planifier) up.

## Decisions

- Added a dedicated `S92ProofTour` (`lib/features/dev/s9_2_proof_tour.dart`,
  gated on `--dart-define=VYBIA_PROOF92=true`, wired in `app.dart`) with two
  deterministic stops (rest, then `debugContactProof`), mirroring the S8.1 tour
  — so the before/after is one reproducible Chrome run, not a hand-driven race.
- Kept the gradient veil deliberately faint (0.30) and bottom-anchored rather
  than dropping it entirely: on the brightest test photo the "touche et décide"
  micro-hint needed a whisper of floor, and a bottom-only veil never frosts the
  hero subject.
