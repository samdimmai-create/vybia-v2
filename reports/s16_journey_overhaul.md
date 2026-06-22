# S16 — Client-journey overhaul (fast-to-value, clear, smooth, ≤3-min)

**Goal:** the founder rated the journey "passable / on se perd, pas clair" on his
phone. S14 added wayfinding but it stayed only passable. S16 aligns the flow to
the validated journey map: R1 fast-to-value first visit, R4 fewest questions /
early-stop, best pick first, R6 no dead-ends, ≤ 3 min to confirm/reserve. This
sprint is STRUCTURE + CLARITY — content variety stays on the S15 Claude layer
(deterministic fallback).

**Machine-safe:** no local heavy build. `flutter analyze` clean, `flutter test`
green (205 tests), cloud build via `./tool/deploy.sh`. Validation = founder on
his iPhone via the live URL.

---

## The new flow — first visit vs return

**Before:** Splash → **Accueil hub (4 abstract directions)** → (Explorer) →
mood → engine loop → reco → Planifier. Every first-timer was dropped on the
abstract hub before seeing any value.

**After (S16A):** the splash decides from the persisted profile:

- **First-time guest** (no saved profile) → **straight to value**:
  Splash → **mood capture (Welcome)** → adaptive questions → **"Meilleur choix
  pour toi"** reveal → Planifier. The hub is skipped entirely — a real
  recommendation is seconds away, not a menu.
- **Returning guest** (saved profile exists) → the calm **Accueil hub** (they
  already know what they want), every branch one swipe away.
- **Hold-to-home → Accueil** stays available from every scene, so the hub is
  always one gesture away even on the first visit.

The first-vs-return decision is `GuestController.returning`, captured once at
construction from `AppStore.readProfileJson()` (a profile is written through on
the very first mood answer, so the 2nd launch onward is "returning").

## The step model (path to a recommendation)

| Step | Scene | Wayfinder | Orb |
|---|---|---|---|
| 1 | Mood capture | **Bienvenue** | 4 moods (Posé / Curieux / Sociable / Plein d'énergie) |
| 2 | Adaptive questions | **Tes goûts** | least-certain dimension, **first batch = 2 Qs** |
| (bridge) | Reflection | — | brief + tap-to-skip |
| 3 | Recommendations | **Pour toi** | best pick first (★ badge), alternatives one at a time |
| 4 | Planifier | **On planifie** | Quand → Avec qui → Confirmer |

Steps before the first reco: **mood + 2 questions = 3 swipes**, then the best
pick. Well under the 3-minute target.

## What was cut / tightened (S16B)

- **`firstBatchSize = 2`** on `LoopController`: the FIRST question batch is capped
  at 2 (down from the 3 of `questionsPerBatch`), so value lands faster; later
  batches keep the full 3 to keep sharpening once the guest is already seeing recs.
- Best-first reveal and early-stop (information-greedy `AdaptiveEngine`,
  `confidentTarget`) were already in place and are preserved.
- The reflection bridge stays brief (~850 ms/slide) and **skippable on touch**.

## What was clarified (S16C)

- The journey indicator (step label + dots) now reads from the **very first
  scene** (Welcome was previously missing it) and **through the planning step**
  (Quand / Avec qui / Confirmer). The full path reads
  **Bienvenue → Tes goûts → Pour toi → On planifie** — no scene starts "lost".
- Every decisive scene keeps its calm phase title, the edge labels (what each
  direction does HERE), the "touche et décide" cue, and the once-per-launch coach
  that names the escape gestures (double-tap = précédent, maintien = accueil).

## No dead-ends (S16D)

End-to-end paths verified:
- **First visit:** Splash → mood → questions → reflection → reco loop → Planifier
  → Mes plans. Hold-to-home → Accueil from anywhere.
- **Return:** Accueil hub → Explorer / Planifier / Mon profil / Mes plans.
- Back contract: double-tap = previous, hold = Accueil; the exhausted tail offers
  "Recommencer". Planifier clears the stack on confirm so the orb flow can't be
  re-entered backwards.

## Decisions

- **First-vs-return signal = persisted profile**, not a separate visit flag — it
  already exists, is written on the first answer, and exactly matches the intent
  (engaged once → you get the hub). To re-test the first-visit path, clear the
  site's local storage.
- **Kept the hub for returning guests** rather than removing it — the cahier's
  4-direction home is the validated return experience; only the *first* visit
  routes around it.
- **Smooth transitions:** kept the standard route transitions (no custom page
  transitioners) to stay low-risk; the reflection bridge already provides the
  calm beat between question batches and recs.
- Fixed a test-only coupling: `accueil_hold_home_test` built `initialRoute:
  '/welcome'` without `onGenerateInitialRoutes`, so Flutter's default also built
  the Splash route and its timer fired mid-test. The test now builds a single
  welcome route, exactly as `app.dart` does in production.

## Verification

- `flutter analyze lib test` → **No issues found**.
- `flutter test` → **205 passing**, including new coverage:
  first-visit → mood, returning → hub, first batch capped at `firstBatchSize`.
- Cloud build + deploy via `./tool/deploy.sh`.

## For the founder

Open the live URL on your iPhone. **Clear the site data first to test the
first-visit path** (Safari → site settings → clear, or use a private tab): the
very first run should reach a real recommendation fast — mood, two quick
questions, then your best pick — without ever touching the abstract hub. Reopen
the app and you'll land on the calm Accueil hub instead. At every step the top
indicator tells you where you are (Bienvenue → Tes goûts → Pour toi → On
planifie), and a hold always brings you home.
