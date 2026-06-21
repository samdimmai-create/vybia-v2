# S14 — Journey clarity + edge-filter fix + selectable palettes

**Branch:** `main` · **Commits:** `e9130dc` (A), `91a6e13` (B), `50bf203` (C)
**Validation:** `flutter analyze` clean · `flutter test` 188 + new tests green ·
no local render (machine-safe rule) → **the founder's iPhone is the proof.**

---

## TL;DR for the founder (do this on your iPhone)

1. Open the live URL (printed by the deploy at the end of this sprint).
2. Reach the recommendation scenes. Touch an image and **slide toward an edge**
   without releasing — you should now clearly SEE the image take on that edge's
   colour (and **drain to grey + darken** when you slide toward *Pas
   intéressant*). That's the fixed filter.
3. Bottom-left there's a small **"Palette A"** chip with 4 colour dots. **Tap it**
   to cycle **A → B → C** live. Compare the edge colours on the real photos.
4. Tell me: **which palette (A / B / C)** you prefer, and whether the journey now
   **reads clearer** (the top "Tes goûts / Pour toi" indicator + the first-run
   hint).

---

## PART A — the edge filter now renders on web  (`S14A`)

### Root cause
The decisive-edge layer had two paths:
- the **colour wave** (non-reject) was a plain `CustomPaint` radial gradient —
  web-safe, but its peak sat on the far *screen edge*, so by the time it reached
  the orb (where you actually look) it had faded to almost nothing → "doesn't
  filter".
- the **reject** (Pas intéressant) drain used **`BackdropFilter` +
  `ShaderMask(dstIn)`**. `BackdropFilter` is unreliable / clipped under Flutter
  **web / CanvasKit** — so the grayscale drain effectively stopped showing on the
  deployed build. (The codebase already abandons GLSL shaders on web for the same
  reason — see `RefractionBubble`'s fallback.)

### Fix (all web-safe — plain canvas + `ColorFiltered`)
- Removed `BackdropFilter`/`ShaderMask` entirely.
- The reject drain is now a real **`ColorFiltered`** wrapper on the hero image
  (`rejectColorMatrix(reach)` lerps the image from full colour → grayscale +
  darken). `ColorFiltered` renders identically on web and mobile.
- Strengthened the colour wave: higher peak (0.82 vs 0.60) **and** added an
  **orb-anchored hotspot** so the tint is unmistakable right where your finger
  is, not only at the screen edge.
- `EdgeDecisiveOverlay` is now 100% `CustomPaint` (radial gradients) → same on
  every platform.

Files: `lib/shared/edge_decisive.dart`, `lib/features/guest/widgets/scene_scaffold.dart`,
`test/edge_decisive_test.dart`.

---

## PART B — 2–3 selectable edge-colour palettes  (`S14B`)

Three cohesive palettes, **one colour per action** (Intéressant / Pas
intéressant / Plus d'infos / Planifier), all in the water/glass/ice/sea-glass
world. Switch them **live** with the bottom-left **"Palette X"** chip (tap to
cycle A→B→C). The whole app — the edge **filter** AND the edge **labels** —
rereads the active palette, and each label now glows the **same colour as the
wave it triggers**.

| Action | A — *Aurore glacée* | B — *Lagune profonde* | C — *Verre pastel* |
|---|---|---|---|
| Intéressant (joy) | `#F2C879` champagne-gold | `#2FD9C3` turquoise | `#E8C9A0` peach-sand |
| Pas intéressant (reject) | `#33454A` slate | `#1E2D33` ink | `#3C4A4E` dove |
| Plus d'infos (curious) | `#86C5E6` glacier blue | `#5C8CF0` cobalt | `#A9C2EE` periwinkle |
| Planifier (go) | `#5FC9A0` sea-glass green | `#3FD17A` spring green | `#9BE0C2` seafoam |
| Neutre | `#8FD4D0` mist | `#5FB7A8` teal | `#BFE3DF` pale aqua |

- **A** = cool ice/glass with a soft warm "yes" (warmth without the harsh gold).
- **B** = deeper, more saturated water-neon — reads strongest on photos.
- **C** = soft pastel glass — calmest, most diffuse tint.

> Note: the selection is **session-scoped** (resets to **A** if you fully reload
> the page). Flip + compare within one session; tell me the winner and I'll set
> it as the permanent default (and add cross-reload persistence) next.

Files: `lib/shared/edge_palette.dart` (new), `edge_action.dart`, `edge_labels.dart`,
`edge_decisive.dart`, `app.dart`, `scene_scaffold.dart`, `test/edge_palette_test.dart`.

---

## PART C — journey clarity ("on se perd")  (`S14C`)

- **"Where am I" indicator** at the top of every orb scene: a short phase label
  over step dots — **Bienvenue → Tes goûts → Pour toi → On planifie**. It's calm
  and low-clutter, rides the rest state, and fades out the moment you touch (so
  it never fights the orb or the top edge label).
- **Stronger first-run coach** (once per launch, first resting scene): now spells
  out the whole orb grammar so you can't get stuck — *"Touche l'image, glisse
  vers un choix"* + *"Double-tap : revenir · maintiens : accueil"*.
- Back/forward are already wired (double-tap = previous, hold = accueil); the
  coach simply **surfaces** them clearly.

Files: `scene_scaffold.dart` (`JourneyStep`, `_JourneyIndicator`,
`_firstRunCoach`, `_PaletteSwitcher`), `reco_screen.dart`, `engine_loop_screen.dart`.

---

## What I could NOT verify here (and why)
No local visual render — this Mac kernel-panics on heavy Flutter builds, so per
the machine-safe rule I ran only `flutter analyze` (clean) and the headless
`flutter test` suite (green). The **visual** truth — does the filter now show,
which palette looks best, does the journey read clearer — can only be confirmed
on your iPhone via the live URL. That's the ask above.
