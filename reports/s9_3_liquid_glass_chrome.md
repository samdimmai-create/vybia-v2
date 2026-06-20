# S9.3 — Liquid-glass info bubble + edge labels

**Goal:** restyle the info-bubble chips AND the edge/choice labels in the orb's
liquid-glass / water / ice / sea-glass language so the whole UI reads as one
material family — while hitting all four balance goals at once: **light**
(never bars the hero image), **distinct** (separable from busy/bright photos),
**on-theme** (sea-glass bead, glass rim, soft glow, fully rounded), **legible**
(glanceable in a second). One commit. Chrome proof, no simulator.

## The glass material — `GlassCapsule` (`lib/shared/glass.dart`)

A new reusable capsule applied to the SMALL chrome elements only (info-bubble
badge + tag chips, the four edge labels), so it never frosts the whole image.
Faked cheaply (gradient + border + two shadows — **no `BackdropFilter`**), so
several sit on screen at ~60fps and the S9.2 no-frosting guarantee still holds.

Material spec (constants):

| Element | Value |
|---|---|
| Radius | `AppRadius.pill` (999 → full capsule, no hard corners) |
| Body gradient (top) | `alphaBlend(white@0.16, tint@bodyTop)` — specular sheen |
| Body gradient (foot) | `AppColors.surface @ bodyBottom` — denser darker foot |
| `bodyTop` / `bodyBottom` | strong: `0.26 / 0.40` · normal: `0.18 / 0.30` |
| Glass rim | `alphaBlend(white@0.45, tint) @ 0.60`, width 1 |
| Glow (distinctness) | `tint @ 0.22`, blur 12, spread −3 |
| Drop (separation) | `black38`, blur 6, offset (0,1) |
| Text | child carries `kGlassTextShadow` + weight `w700` |

`strong: true` (badge + edge labels) gives a touch more body/rim than the
secondary tag chips, so the hierarchy survives the translucency.

`kGlassTextShadow` (shared, was the S9.2 `_kBubbleTextShadow`): tight
`black, blur 4` glyph-hug + wide `black87, blur 14` lift — the reason text stays
instantly legible without any opaque panel.

## Where it's applied

- **Info bubble** (`_BottomBubble`): badge `★ Meilleur choix pour toi` →
  `GlassCapsule(tint: champagne, strong)`; tag chips `• posé / • calme / • cosy`
  → `GlassCapsule(tint: accent)`. The **title / pourquoi / info line / hint stay
  FLOATING TEXT** with `kGlassTextShadow` (no panel) so reading is instant —
  dew beads on the photo, not a UI card.
- **Edge / choice labels** (`EdgeLabels._Chip`): every orb scene (reco, mood,
  accueil) → `GlassCapsule(tint: edge colour, strong)`, each keeping a glassy
  tint of its decisive action — Intéressant **gold** (`edgeLeft`),
  Pas intéressant **slate-cyan** (`edgeRight`), Plus d'infos **lavender**
  (`edgeUp`), Planifier **sea-glass green** (`edgeDown`). Label glyph is the
  edge colour lifted toward pearl (`alphaBlend(white@0.30, color)`) + the
  shadow, so it stays legible over its own tint on any background.

## Four balance goals — bright vs dark

Verified on two background extremes (a bright daylit market vs a dark cocktail
bar):

- **Light** — body alphas are low (0.18–0.40) and there's no backdrop blur, so
  the photo reads through every chip on both backgrounds; the floating title/
  description never sits on a panel.
- **Distinct** — the white-tinted rim + the tinted glow halo lift each bead off
  even the busy bread photo and the dark glassware, so nothing dissolves into
  the image.
- **On-theme** — translucent sea-glass body, top specular sheen, bright glass
  rim, soft glow, fully-rounded capsule = the orb/bubble/ice material; no square
  or hard-angled corners on any chrome element.
- **Legible** — `kGlassTextShadow` + `w700` + the brightened glyph colour keep
  every label glanceable in a second on bright and dark alike.

## Label-consistency check

The reco reaction edges already read **Intéressant / Pas intéressant / Plus
d'infos / Planifier** in `reco_screen.dart` (verified) and the proof tour uses
that exact set — consistent on every reco scene.

## Verification

- `flutter analyze` — **No issues found.**
- `flutter test` — **112 passing.** Updated the S8.1D bottom-bubble test
  (`expect(find.byType(GlassCapsule), findsWidgets)` at rest for the badge/tags,
  alongside the retained `BackdropFilter findsNothing`), and the edges test
  (GlassCapsule on contact for the choice labels).
- `flutter build web --release` — **OK** (`VYBIA_PROOF93=true`).
- Chrome proof (visible window via `tool/web_shoot.sh` + `tool/cdp_capture.mjs`,
  page-targeted DevTools screenshots, no simulator):
  - `screenshots/s9_3_info_glass_bright.png` — info bubble over a bright market
    photo: glass badge + tag beads distinct, image through, text instant.
  - `screenshots/s9_3_info_glass_dark.png` — same over a dark cocktail photo.
  - `screenshots/s9_3_edges_glass.png` — reco scene on contact: four tinted
    glass choice labels + the orb.

## Decisions

- **No `BackdropFilter` on the chips.** A per-chip blur would be the most
  literal "glass," but it (a) reintroduces frosting the S9.2 test locks out and
  (b) costs more with several chips on screen. The gradient + specular + rim +
  glow recipe reads convincingly as a glass bead while staying cheap and keeping
  the no-frosting guarantee — the better balance for the four goals.
- **Badge tinted champagne** (not brand teal): it's the "best pick" accolade, so
  a warm sea-glass bead distinguishes it from the cyan/teal tag + info chips
  while staying in the palette.
- Added `S93ProofTour` (`lib/features/dev/s9_3_proof_tour.dart`, gated on
  `--dart-define=VYBIA_PROOF93=true`, wired in `app.dart`) with bright/dark/edges
  stops so the balance is one reproducible Chrome run.
