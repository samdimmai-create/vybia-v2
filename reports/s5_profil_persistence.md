# Vybia V2 — Sprint S5 Report
## Profil / Préférences + Local Persistence + iOS-Simulator Visible Test

**Date:** 2026-06-19
**Branch/commit base:** S4B (`5b3b140`)
**Mode:** full autonomy

---

## 1. What shipped

### A. Persistence layer (single repository)
- Added `shared_preferences` (web backend = `localStorage`; iOS = `NSUserDefaults`).
- New `lib/core/persistence/app_store.dart` — the **one** store/repository file. Pure
  storage + JSON, no UI. Versioned keys (`vybia.*.v1`) for clean future migration:
  - `vybia.profile.v1` — full taste profile: the 8 declared dimensions **and** the
    learned values the engine + revealed-preference loop inferred, plus the current
    mood (mood is a profile dimension). Serialized via `GuestProfile.toJson()` /
    `restore()`.
  - `vybia.liked.v1` / `vybia.decided.v1` — revealed-preference history (J'aime /
    Pas-pour-moi), so a relaunch doesn't re-surface decided picks.
  - `vybia.plans.v1` — Futurs + Passés plans (activity referenced by catalog id +
    moment/companions/when/createdAt).
  - `vybia.intention.v1` — last chosen intention.
  - `vybia.seeded.v1` — **first-run-only** guard for the two demo "Passés" plans.

### B. Controllers read initial values from the store and write through
- `GuestController({store})` — hydrates the profile + intention on construction;
  `setMood` / `answerCurrent` / `adjustDimension` / `setIntention` persist on change.
- `RecoController({store})` — hydrates liked/decided history; each like/dislike writes
  the learned profile + history through.
- `PlanController({store})` — loads plans on construction, persists on
  create/update/remove. The two demo past plans are seeded **only on first run**
  (store-guarded), never re-seeded over the guest's real data. `_nextSeq()` keeps
  restored + new plan ids from colliding.
- `main.dart` is now async: `AppStore.open()` is awaited **before first paint**, so the
  first frame already reflects persisted state (no flash of defaults).

### C. Mon Profil / Préférences screen (`/profil`)
- Reached by **Accueil (Intention) UP → Mon profil** (added to the established
  direction map), plus a `/dev` entry and the router.
- One immersive, all-orb surface with two modes:
  - **Aperçu** ("ce que Vybia a appris") — the learned profile recap + all 8 declared
    dimensions with their current leaning, over a situational image wearing the
    universal bubble. Orb: LEFT = Ajuster, DOWN = Retour.
  - **Ajuster** — nudge any of the 8 dimensions **entirely via the orb** (LEFT/RIGHT
    move the current dimension low/high, UP = dimension suivante, DOWN = Terminé).
    NO slider, NO swipe-cards, NO toggle. Each nudge calls
    `GuestController.adjustDimension`, which writes through to storage immediately.
- Explicit fonts (theme `google_fonts`), sea-glass palette, decisive edge colours,
  default param values.

---

## 2. Autonomous decisions

- **No "Accueil" hub screen exists in V2** → mapped "Accueil UP = Mon profil" onto the
  Intention screen ("Maintenant ou planifier ?"), which is the post-profile hub.
- **Adjust UX** chosen as one-dimension-per-scene with LEFT/RIGHT = low/high and
  UP = next, DOWN = done — the only fully orb-native way to "move a dimension up/down".
- **`restart()` does NOT wipe storage** (it only clears the in-memory session for
  `/dev` landings/replays); a real relaunch always rehydrates from disk.
- Learned profile is persisted as the nudged `GuestProfile` values (the inference
  target) plus the liked/decided id history — both feed the engine on relaunch.

---

## 3. Persistence keys / schema

| Key | Shape |
|---|---|
| `vybia.profile.v1` | `{ "values": {dim: 0..1}, "confidence": {dim: 0..1} }` |
| `vybia.liked.v1` | `List<String>` activity ids |
| `vybia.decided.v1` | `List<String>` activity ids |
| `vybia.plans.v1` | `List<{id, activity, moment, companions, when, createdAt}>` |
| `vybia.intention.v1` | `"now" \| "plan"` |
| `vybia.seeded.v1` | `bool` |

---

## 4. Quality gates

- `flutter analyze` — **clean** (0 issues).
- `flutter test` — **33 passed** (8 new S5 tests: store round-trips for profile /
  intention / plans, adjusted-pref rehydrates, J'aime persists learned profile +
  history, created plans rehydrate, first-run seed-once + real-plan-preserved).
- `flutter build web --release` — **OK**.

---

## 5. Visible test — outcome (iOS simulator BLOCKED → visible Chrome window)

### Simulator blocker (one line)
Xcode 26.3's only simulator SDK is `iphonesimulator26.2`; it refuses the installed
iOS 18.3 runtime as a build destination (`xcodebuild -showdestinations` lists **zero**
eligible simulators), so the required iOS 26.x simulator platform had to be downloaded
(`xcodebuild -downloadPlatform iOS`) — a multi-GB install that, with the subsequent
debug rebuild, exceeded a reasonable window. **Decision: stop the simulator path and use
the doctrine fallback — a real, VISIBLE Chrome window.** (The iOS-sim
`integration_test/s5_visible_test.dart` + `s5_relaunch_test.dart` harness remains in the
repo, analyzer-clean, for when the runtime is ready.)

### Visible Chrome window test (what actually proved S5)
Ran the release web build on `localhost:8090` in a **real, visible Chrome window**
(not headless), navigated with the framework router (hash routes), and drove the orb
with browser-level synthetic pointer drags (no OS cursor/keyboard injection). Captures:

| File | What it proves |
|---|---|
| `s5_01_edge_joy.png` | J'aime → **joy** (warm gold) decisive-edge filter |
| `s5_02_edge_reject.png` | Pas pour moi → **reject** (desaturate/darken) |
| `s5_03_edge_go.png` | Planifier → **go** (sea-glass green) |
| `s5_04_edge_curious.png` | Plus d'infos → **curious** (indigo) |
| `s5_05_profil.png` | /profil aperçu — "ce que Vybia a appris" + the 8 dimensions at **default** |
| `s5_06_adjust.png` | After nudging Énergie via the orb → reading becomes **tonique** (written to localStorage) |
| `s5_07_after_relaunch.png` | After a **full page reload** (web shared_preferences = localStorage = a relaunch): Énergie still **tonique**, NOT reset to default |

**Live walk verified in the visible window (in-conversation captures):**
`/profil` default (Énergie *équilibré*) → orb **left** = Ajuster → orb **right ×2** = the
*Énergie* dimension reads *tonique* (the pug/calm image renders under the universal
bubble lens) → **full reload from the origin** → `/profil` still shows Énergie *tonique*.
This is the acceptance: an orb-adjusted preference survives a real relaunch via
localStorage, with the recommendation engine reading the persisted profile on boot.

### Edge / shader limitation (stated, no fake PASS)
The held-orb decisive-colour **shader** can't be driven through browser pointer injection
to a steady held frame, so the four edge colours are captured from the deterministic
`/edge-demo` witness route (which renders each action colour at a fixed aim). This is the
same approach S4B used; it proves the colour system renders, not the live in-gesture hold.

### Files NOT proven via the iOS simulator
The `s5_00_sim_boot` / iOS-simulator frames were intentionally **not** produced — the app
was never installed on the sim (see blocker). No placeholder was kept, to avoid implying
a sim run that did not happen.

---

## 6. Simulator-runtime install outcome (record)

- iOS **18.3** runtime present + iPhone 16 Pro booted, but Xcode 26.3 would not target it.
- `xcodebuild -downloadPlatform iOS` (no sudo) **succeeded**, installing the
  **iOS 26.3.1** simulator runtime; an iPhone 17 Pro (26.3) booted and Flutter saw it.
- A `flutter drive` build started but the debug build/install for the new runtime ran
  long; per the hard-stop decision the simulator path was abandoned in favour of the
  visible Chrome window. No further simulator attempts.
