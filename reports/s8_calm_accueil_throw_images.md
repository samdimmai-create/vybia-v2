# Sprint S8 — Calm Accueil · Orb Throw (momentum) · Category-accurate images

**Workspace:** `~/Desktop/vybia-v2` · **City:** Montréal · **Base:** S7 (`d15f7d7`, MVP complete)
**Status:** `flutter analyze` clean · `flutter test` 59 green · `flutter build web --release` OK
**Visible test:** iOS Simulator (iPhone 17 Pro, iOS 26.3) via the programmatic proof tour
(`--dart-define=VYBIA_PROOF=true`), captured with `xcrun simctl io booted screenshot`.

S8 closes the three rough edges the founder called out on the S7 MVP:
1. the hold-to-home GROW looked scary (it swirled the activity image into a vortex);
2. there was no orb THROW / momentum (V1 had it);
3. images were generic / mismatched (strawberries behind a theatre, a lion behind a mood question).

---

## Part A — Calm Accueil + non-scary hold-to-home  (`S8A`)

### Calm Accueil hub (`/accueil`)
- New `AccueilScreen` (`lib/features/guest/screens/accueil_screen.dart`) — the app's hub and the
  destination of hold-to-home. It is **not** tied to any activity image.
- New reusable `CalmHomeField` (`lib/components/bubble/calm_home_field.dart`): a procedural
  sea-glass **water / ice / glass** field — a soft vertical wash + three slowly drifting pools of
  pearl / cyan / teal light + faint icy caustic streaks + a gentle vignette. No purple, no black
  void, restful, self-animating (14 s drift loop). Explicit fonts via the theme.
- Hosts the **cahier directions** on the orb: `gauche = Explorer · droite = Planifier ·
  haut = Mon profil · bas = Mes plans`. Labels are always visible here (a hub should make its
  choices legible at a glance). `enableHoldHome: false` (already home → a still hold is a no-op).
- **Routing:** Splash now lands on `/accueil` (was `/welcome`); hold-to-home everywhere routes to
  `/accueil` (was `/welcome`); Welcome (the Explorer entry) now allows hold-to-home back to the hub.

### Non-scary hold-to-home transition
- The grow no longer magnifies the activity photo. The refraction bubble keeps its calm **contact**
  size and its activity refraction *recedes* (`active * (1 − 0.7·hold)`).
- Instead a **CalmHomeField portal** — the same neutral home imagery — expands from the orb as a
  growing circle (`_CircleReveal` clip), cross-fading in (`opacity = clamp(hold·1.4, 0, 1)`) and
  growing to cover the screen (`radius = lensRadius·(1 + hold·16)`). It reads as a calm portal
  opening to home, never a vortex. On completion → land on the calm Accueil.

**Transition timings** (unchanged contract, S7): immobile threshold `holdStill = 3 s` → warning
begins; `holdGrow = 1 s` portal open → navigate. Any movement past 16 px jitter, or a release before
completion, cancels cleanly (no nav, no commit). Release-mid-warning dissolves in 160 ms.

---

## Part B — Orb throw / momentum (V1 parity)  (`S8B`)

A quick **flick** — a release below the commit distance but above a velocity threshold — throws the
orb. It travels ballistically along the release **direction + force**, on a gently **curved** path,
with **friction**. If it reaches a decisive edge it **commits** that direction (same action, same
decisive colour as it nears); if it runs out of momentum first it **dissolves**, no commit. Every
flight ends in commit OR dissolve — never a freeze.

### Coexistence with the existing gestures
- slow drag-to-aim + release past `threshold` (72 px) → **commit** (deliberate; wins over throw);
- quick flick (sub-threshold, speed ≥ `throwVelocity`) → **momentum**;
- still immobile hold → **hold-to-home**;
- double-tap → **back**.
- A fresh touch mid-flight cleanly interrupts the flight. All timers + the flight ticker are
  cancelled before any commit.

### Physics constants (`lib/components/orb/orb_throw.dart`, pure & unit-tested)
| Constant | Value | Meaning |
|---|---|---|
| `throwVelocity` (widget) | **720 px/s** | release speed that turns a sub-threshold release into a throw |
| `friction` | **1.7 /s** | exponential, frame-rate-independent velocity decay |
| `curveRate` | **0.8 rad/s** | constant angular drift (seeded by the throw's horizontal sign) → the arc |
| `stopSpeed` | **150 px/s** | speed below which a throw that hasn't reached an edge dissolves |
| `edgeMargin` | **44 px** | how close to a screen edge counts as "reached" (commit only while still heading in) |

The motion is factored into a Flutter-free `ThrowSimulation` so it is deterministically unit-tested
(`test/orb_throw_test.dart`): strong throw → commit (correct direction), upward flick → commit up,
weak throw → dissolve (no commit), reach → 1 as it nears the edge. The `VybiaOrb` drives it from a
`Ticker`; the orb (and, in scenes, the refraction bubble + decisive-edge colour) ride the flight.

---

## Part C — Category-accurate images  (`S8C`)

S7 reused 8 illustrative images across 12 OSM categories, producing the worst mismatches
(café = a canal town, bar = a clothing store, cinema = **strawberries**, "energetic" = **a lion**,
mood = **a pug**). S8 bundles **one category-accurate, free-licensed photo per used category** plus
four sensible mood images, mapped to each real place by its **real category**.

- Sourced from **Wikimedia Commons** via the API (`tool/source_images.py` + `tool/source_candidates.py`),
  each visually reviewed; 4 first-pass picks were rejected and re-sourced (social = sheet music,
  energetic = a celebrity, theatre = a building exterior, gallery = a 1939 B&W scan).
- `places/` (12): cafe, restaurant, bar, cinema, theatre, museum, gallery, viewpoint, park, garden,
  market, sports — `emotions/` (4): calm, curious, social, energetic. Total ≈ 6.1 MB.
- Each place → its own image in `place_category_mapping.dart` (a café shows a café, a theatre shows a
  theatre). The mood/preference question bank + the welcome mood capture + the planifier scenes
  (which inherit the activity's image) are now all contextually sensible. The universal bubble works
  on every one.
- Full per-image **author + licence + source** in `assets/images/NOTICES.md` (bundled). Licences:
  CC0 / Public domain / CC BY / CC BY-SA (2.0–4.0). Notable: viewpoint = the real **Kondiaronk
  Belvédère, Montréal**.

### Category → image map
| Category | Image | Category | Image |
|---|---|---|---|
| cafe | `places/cafe.jpg` | park | `places/park.jpg` |
| restaurant | `places/restaurant.jpg` | garden | `places/garden.jpg` |
| bar | `places/bar.jpg` | market | `places/market.jpg` |
| cinema | `places/cinema.jpg` | sports | `places/sports.jpg` |
| theatre | `places/theatre.jpg` | (mood) calm | `emotions/calm.jpg` |
| museum | `places/museum.jpg` | (mood) curious | `emotions/curious.jpg` |
| gallery | `places/gallery.jpg` | (mood) social | `emotions/social.jpg` |
| viewpoint | `places/viewpoint.jpg` | (mood) energetic | `emotions/energetic.jpg` |

> S9 note (NOT done here): fully per-activity, adaptive, non-generic imagery (a unique fitting image
> per specific recommendation) is part of the engine deepening. S8 only removes the worst category
> mismatches.

---

## Part D — Proof + polish

- **Screenshots** (`./screenshots/`, iOS sim via the proof tour): `s8_accueil_calm.png`,
  `s8_reco_cafe.png`, `s8_reco_theatre.png`, `s8_hold_to_home_calm.png`, `s8_throw_commit.png`.
- **`flutter analyze`** clean. **`flutter test`** 59 green (was 51) — added: throw reaches edge →
  commits; short throw → dissolves; reach grows toward the edge; hold-to-home lands on Accueil;
  every place category maps to its own distinct `places/` image. All prior tests kept
  (idle-no-paint, persistence, interaction model, geo, engine).
- **`flutter build web --release`** OK.

## Decisions (full autonomy)
- **Splash → Accueil** (not straight to Welcome): the calm hub sets the tone and is explicitly
  endorsed by the cahier ("a calm landing with a clear way back into the flow"). Explorer is one
  calm tap away.
- **Planifier from the hub** routes to `/plan` (bare → first catalog activity renders) since a
  from-scratch plan has no chosen activity yet.
- **Throw vs drag-commit:** a release already past `threshold` commits immediately (deliberate aim
  wins); the throw path only triggers for sub-threshold flicks, so the two never fight.
- **Images:** Wikimedia Commons (clean licences, bundle-able with attribution) over Unsplash/Pexels
  hotlinks; each image hand-reviewed; the proof tour shows representative real Montréal venue names
  (Café Olimpico, Théâtre du Nouveau Monde) under the category images — the live per-category mapping
  is proven on the full OSM snapshot by `test/place_image_test.dart`.
