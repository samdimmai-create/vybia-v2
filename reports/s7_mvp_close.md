# S7 — Orb interaction model + real OSM Montréal + geolocation + final polish (MVP CLOSE)

Final sprint. Delivered in four committed parts (A→D). Pure Flutter, web-first,
deterministic on-device engine (no LLM, no runtime network). Visible tests on the
iOS simulator (iPhone 17 Pro, iOS 26.x) via the programmatic auto-drive proof
path (no TestGesture → no crosshair).

## PART A — Orb interaction model (commit `S7A`)

The founder spec, applied to **every** orb scene through the shared
`SceneScaffold` + `VybiaOrb`.

- **Rest state** (no contact): only the hero image + description (headline +
  one-line "pourquoi"). Edge labels, the guidance chip and the orb are hidden.
  A one-time, app-launch-scoped coach mark ("Touche l'image pour explorer")
  greets a brand-new guest, then never reappears.
- **On contact**: the orb is born (~150 ms fade + scale-in) and the edge labels
  + guidance chip fade IN together (driven by the orb's `presence` signal);
  they fade OUT together on release/cancel.
- **Double-tap** (two still taps within **320 ms**, ≤26 px apart): fires
  `onDoubleTap` → back / undo the current scene. No edge is committed.
- **Hold-to-home** (immobile contact): a stillness timer of **3 s** (cancelled by
  any movement past a **16 px** jitter — i.e. aiming an edge) starts a warning
  ("Continue de maintenir pour revenir à l'accueil") and the orb **grows
  progressively** over **~1 s** (`holdGrow`). Held to completion → navigate to
  the accueil. Released at any point before completion → the orb shrinks &
  dissolves with **no navigation and no edge commit**.
- **Anti-freeze**: every timer (dissolve, immobile, hold) is cancelled before any
  commit (edge / home / double-tap) and the state machine hard-resets on
  pointer-up AND pointer-cancel — the orb can never freeze, including on home
  return (V1's #1 bug, designed out).

Thresholds (all overridable on `VybiaOrb`): `threshold` 72 px to commit an edge,
`holdStill` 3 s, `holdGrow` 1 s, double-tap window 320 ms, jitter 16 px,
hold-grow factor ×9.

Sim proof: `s7_a1_rest_clean`, `s7_a2_contact_edges`, `s7_a3_hold_home_warning`,
`s7_a4_release_shrink`.

## PART B — Real OSM Montréal snapshot (commit `S7B`)

- **Source**: OpenStreetMap (© OSM contributors, ODbL) via the **Overpass API**
  (`overpass-api.de`), fetched **build-time, one-off, 2026-06-20** into the
  bundled asset `assets/data/montreal_places.json` (~30 KB). No runtime network.
- **Overpass query** (bbox `45.40,-73.74 → 45.61,-73.47`, name-bearing nodes):
  `amenity` cafe/restaurant/bar/pub/cinema/theatre/marketplace; `tourism`
  museum/gallery/viewpoint; `leisure` park/garden/sports_centre/fitness_centre.
  Raw 4 144 named POIs → curated, deduped (name+rounded coords), capped per
  category → **297 places** (restaurant 55, cafe 45, sports 40, bar 35, gallery
  25, museum 20, theatre 20, garden 14, viewpoint 13, cinema 12, market 10,
  park 8).
- **Model + repository**: `Place` / `PlaceCategory` (tolerant JSON parsing) and
  `OsmPlaceRepository` (loads the asset once at startup, exposes real places +
  engine activities + id lookup). Reco loop, planner and persistence all read
  this live catalog; the hand-authored seed catalog stays as a fallback.
- **Category → 8-dimension mapping** (`place_category_mapping.dart`, documented):
  each OSM category maps to a curated profile on the engine's eight axes
  (energy/social/novelty/distance/indoor/timing/budget/vibe) + motives + budget +
  indoor/season + an illustrative image (mapped from the existing image set, so
  the universal bubble always has real content) + a French description template
  woven with the real place name + neighbourhood.
- **Diversity**: a greedy category spread in the engine keeps the visible queue
  from being five near-identical venues (essential with hundreds of real
  cafés/restaurants).

Each recommendation is now backed by a real place — e.g. *Le Studio TD*,
*Théâtre du Rideau Vert* — with a real name, category and location.

## PART C — Geolocation + distance-aware reco (commit `S7C`)

- **`core/geo`**: haversine distance, Montréal-centre fallback
  (**45.5019, −73.5674**), `GeoResult`/`GeoStatus`, FR distance/ETA formatting
  ("à 2,3 km · ~15 min").
- **`LocationService`**: browser geolocation on web (`dart:html`, conditional
  import); off-web / denial / no fix → Montréal-centre fallback. Requested **only
  once the guest has reached the recommendations** (value first, never a hard
  gate) and **never blocks** the flow. Status persisted (`vybia.geo.v1`).
- **Engine**: real haversine distance folds into the `distance` taste axis, plus
  a small proximity reward so nearer real places rank up; the feasibility filter
  drops places out of region (>25 km) and far ones for guests who confidently
  prefer nearby. `Recommendation.distanceKm` is shown on the card and in
  "Plus d'infos" ("à X km · ~Y min").
- **Reranking proven**: same neutral profile, two locations → the top pick
  changes — *Le Studio TD* (531 m) from Montréal centre vs *Théâtre du Rideau
  Vert* (4,4 km) from a north location. Sim proof `s7_03_reco_real_place` /
  `s7_04_reco_after_move`. A debug `--dart-define=VYBIA_GEO=lat,lng` injects a
  location for the visible reranking proof; the iOS simulator has no real fix so
  it exercises the fallback path by default.

## PART D — Final polish + full visible walkthrough (commit `S7`)

- The Part A interaction model is applied across the whole journey via
  `SceneScaffold` (Welcome, discovery questions, reco, planifier, every
  orb scene). Welcome (the accueil) disables hold-to-home (it would be a no-op).
- Reco prompt grew to 4 lines so the distance line never clips; the "pourquoi"
  no longer states a vague distance (shown explicitly instead).
- `flutter analyze` clean; `flutter test` green (51 tests); `flutter build web
  --release` OK.

### Consolidated walkthrough (./screenshots)

`s7_01_welcome` (mood capture, rest), `s7_02_mood` (adaptive question),
`s7_03_reco_real_place` (real Montréal name + "à X km"), `s7_04_reco_after_move`
(different location → reranked), `s7_05_plus_infos` (detail + distance),
`s7_06_planifier`, `s7_07_mes_plans`, `s7_08_profil`, `s7_09_after_relaunch`
(persistence: profile + plan + location survive a relaunch).

### Persistence end-to-end

`shared_preferences` (`vybia.*.v1`) holds profile (declared + learned), mood,
liked/decided history, intention, plans and the geo status. Proof: a run with
`--dart-define=VYBIA_SEED_DEMO=true` writes an adjusted taste + a future plan +
a granted location **through the real store**, then a normal relaunch reads them
back (`s7_09_after_relaunch`).

## Autonomous decisions

- **Hybrid visible-test tooling**: macOS ships bash 3.2 (no associative arrays)
  and has no `timeout`; `script` needs a TTY it doesn't get non-interactively;
  `flutter run` quits on stdin EOF in the background. Fix: capture scripts use a
  kept-open fifo for stdin and run `flutter run` directly (no `script`), snapping
  with `xcrun simctl io booted screenshot`. Scripts: `s7a_capture.sh`,
  `s7_shot.sh`, `s7_walkthrough.sh`.
- **Distance fragment removed from the "why"** to avoid a vague "à deux pas"
  contradicting the precise "à X km" now shown on the card.
- **Category diversification** added to the engine so real OSM density doesn't
  collapse the queue into one venue type.
- **Image set reuse**: 12 OSM categories map onto the existing 8 illustrative
  images (a known visual approximation for some categories, e.g. a concert hall
  showing the "curious" image) — acceptable for the MVP image budget; a
  category-accurate image set is post-MVP.

## MVP STATUS vs cahier des charges §9

1. **Parcours invité complet, jouable de bout en bout (Chrome)** — ✅ Splash →
   Welcome → préférences/mood → Reco → Planifier → Mes Plans → Profil; web
   release build OK.
2. **Orbe stable (zéro freeze) partout** — ✅ single `VybiaOrb` engine, all timers
   cancelled before commits, hard reset on up/cancel, anti-freeze on home return;
   covered by interaction tests.
3. **Recos qui changent selon préférences + mood (+ contexte/distance)** — ✅
   deterministic scorer over 8 axes + mood-driven motives + real distance;
   reranking proven with profile AND location.
4 / 4b. **Effet bulle sur image, partout ; chaque activité a une image** — ✅
   universal refraction bubble on every scene; every OSM activity carries an
   illustrative image (no nude gradients).
5. **Plan créable + visible dans Mes Plans** — ✅ orb planifier flow →
   `PlanController` → Mes Plans (Futurs/Passés).
6. **Préférences/plans persistés entre deux ouvertures** — ✅ `shared_preferences`,
   proven across a real relaunch.
7. **1 fichier/module léger + preuve visuelle par module** — ✅ modular feature
   tree; screenshots per surface.

**MVP COMPLETE.**
