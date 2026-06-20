# Sprint S9 — The Adaptive Engine (core)

**Workspace:** `~/Desktop/vybia-v2` · **Base:** S8.1 (`8bc0bdc`) · **Mode:** full autonomy,
deterministic (no LLM), commit per part.

The engine is now a **loop, not a one-shot**: mood → a small question batch →
reflection → a round of recommendations reacted with *Intéressant / Pas
intéressant* → (if no selection) a new batch targeting what's still uncertain →
… → ends when the guest hits **Planifier**. Built on the validated S8.1 base,
pure Flutter, web-first, orb-choice-first.

## Commits (one per part)

| Part | Commit | What |
|---|---|---|
| 0 | `ea01c35` | Orb 1:1 instant tracking |
| A | `e5437ee` | Intéressant / Pas-intéressant reaction model |
| B | `38e126d` | Adaptive question↔reco loop (LoopController) |
| C | `316277b` | Latent profile + 4-motive LMS learning |
| D | `00cd140` | Life-context model + feasibility |
| E | `a50707b` | Context-aware, diversity-conscious scorer |
| F | `1eb4beb` | Bespoke templated content + smart image pick |
| G | _this_ | Proof + polish + report |

`flutter analyze` clean throughout; **110 → 112 tests green**; `flutter build web
--release` OK. All prior S0–S8.1 tests kept.

---

## Part 0 — Orb responsiveness (1:1)

Audit conclusion: there was **no positional lerp/easing to remove** — the orb and
the refraction bubble were already drawn at the exact contact point
(`_current = e.localPosition`, `orbCenter = _orb`), frame-synced via `setState`.
The only orb animation is *presence* (birth/dissolve opacity+scale), which is
what the spec wants kept.

The founder-perceived "lag" on web was **frame-rate**: the fallback `_LensPainter`
resampled the full image 14× per frame (annuli) + 2 chromatic passes, dropping
frames under a fast drag so the lens visually trailed. Fix: rings **14 → 9**
(keeps the droplet curve, restores 60fps). iOS/GLSL path untouched. Locked the
1:1 contract with a regression test (position stream == exact pointer on every
move) and a "do not add positional smoothing" note at the move handler.

## Part A — Reaction model

Reco edges: **LEFT Intéressant · RIGHT Pas intéressant · UP Plus d'infos · DOWN
Planifier**. Intéressant/Pas-intéressant are *revealed-preference reactions* that
feed the profile and re-rank the next scene; **only Planifier selects** an
activity and ends the loop. Decisive edge-wave colours by meaning were already
correct (joy = warm gold, reject = desaturate+darken, curious = indigo, go =
green). `RecoController.like()/dislike()` → `markInteresting()/markNotInteresting()`.

## Part B — The adaptive loop (state machine)

`LoopController` (pure logic, no widgets) is an explicit state machine:

```
        ┌──────────────────────────────────────────────┐
        ▼                                                │ (round budget spent,
   [questions] ──answers(batch)──▶ [reflection] ──done──▶ [recos] ──not done──┘
        ▲                                                │
        │                                          select│ (Planifier)
   (new batch targeting                                  ▼
    the uncertain dims)                             [selected]  ──▶ Planifier
                                                         
   recs run out ─────────────────────────────────▶ [exhausted]
```

- A tiny engine-chosen **question batch** (`questionsPerBatch`, default 3)
  sharpens the profile, bridges through the reflection, opens a **reco round**.
- Reactions feed the profile and re-rank live (`RecoController.refresh()` between
  rounds). Once a round's budget (`recosPerRound`, default 4) is spent without a
  selection, the loop **inserts a new question batch** targeting the still-
  uncertain dimensions — alternation — bounded by `maxRounds` (default 4).
- **Convergence:** each batch raises `GuestProfile.confidentCount`; once the
  adaptive engine is confident it stops inserting batches and just serves recs.
  Ends on Planifier (`select`) or drains to `exhausted` — never stuck.

Composes the proven `AdaptiveEngine` (info-gain question pick) + `RecoController`
(revealed-preference state). `EngineLoopScreen` renders each phase; `/engine`
route; Welcome's mood hands off to the loop.

## Part C — Latent profile + learning (4-motive LMS)

The latent taste vector (8 dims + per-dim confidence), revealed-preference nudges,
anti-repetition (`_decided`) and info-gain question selection already existed and
persist through `vybia.profile.v1`. Added the richer motive model:

**Beard & Ragheb Leisure Motivation Scale** — four components:

| LMS motive | Guest weight ← profile | Activity affinity ← |
|---|---|---|
| INTELLECTUAL | 0.6·novelty + 0.4·curiosity(mid-mood) | 0.5·novelty + 0.3·eudaimonic + culture/creative |
| SOCIAL | 0.6·social + 0.4·(½vibe+½mood) | 0.55·social + 0.25·vibe + 0.2·hedonic |
| COMPETENCE-MASTERY | 0.5·energy + 0.3·mood + 0.2·novelty | 0.5·energy + 0.3·eudaimonic + active/nature |
| STIMULUS-AVOIDANCE | 0.5·(1−energy) + 0.35·(1−mood) + 0.15·(1−social) | 0.45·(1−energy) + 0.35·relaxation + 0.2·(1−social) |

Guest weights are normalized (sum ≈ 1). The four motives are a **derived readout**
of the latent profile, not independent stored state, so they can never drift out
of sync. `match = Σ weightᵢ·affinityᵢ`. `dominant()` exposes the strongest motive
for tone (S9F).

## Part D — Life-contexts + feasibility

Durable real-world situations captured implicitly at the orb, persisted with the
profile (`contexts` in `vybia.profile.v1`). Grounded in the leisure-constraints
literature (intrapersonal / interpersonal / structural). **Context → filter table:**

| Context | Family | Drops |
|---|---|---|
| Avec des enfants | interpersonnel | nightlife · strictly late-night (timing>0.85) |
| Sans alcool | intrapersonnel | nightlife (bars/clubs) |
| Budget serré | structurel | splurges (budget tier 3) |
| Mobilité réduite | intrapersonnel | active · energetic nature · >8 km |
| Sans voiture | structurel | >6 km (across town) |
| Avec un animal | interpersonnel | pet-unfriendly indoor (culture · nightlife) |

Hard feasibility filter in the engine; the existing starve-guard falls back to
the unfiltered pool if a pile-up of contexts would blank the scene. Each context
also carries a `toneFr` fragment folded into the "pourquoi" (S9F).

## Part E — Scoring + recommendations

```
score = 0.42·prefMatch + 0.20·lmsMatch + 0.14·contextFit + 0.09·socialFit
      + 0.10·(noveltyPref·novelty) + 0.12·(1−farness) − 0.06·categoryRepeat
then: life-context + feasibility filter
   → diversity-aware ranking (category spread + near-duplicate-venue guard)
   → DOSED serendipity
   → best pick first, then 4–6 alternatives one at a time at the orb
```

New in S9E: **near-duplicate guard** (two same-category venues within 0.4 km read
as duplicates — keep the better) and **dosed serendipity** (unless the guest is
confidently novelty-averse, the batch is guaranteed one non-lead *discovery*,
novelty ≥ 0.7, swapped in for the weakest alternative — controlled surprise, never
random, never stealing the genuine best pick). contextFit covers time-of-day +
season; weather has no data source yet (noted for later). Each card shows real
haversine distance ("à X km") and a tailored "pourquoi".

## Part F — Bespoke content + smart image (LLM-swappable)

`ContentProvider` interface is the seam for a future LLM brain — swap
`TemplatedContentProvider` for an `LlmContentProvider` and nothing else changes
(proved by a fake-provider test). The shipped templated provider:

- **why():** folds the dominant LMS motive + up to two matched axes + active
  life-context tone into one of four sentence shapes (chosen by activity id), so a
  batch reads tailored and never repeats verbatim. Deterministic.
- **imageFor():** narrows to the activity's category, then picks the candidate
  best matching the blended (activity + guest) vibe — a calm guest gets a calmer
  culture image, a lively one a livelier image. Carried as
  `Recommendation.imageOverride` (`rec.image`); both reco screens use it.

**What stays for the LLM upgrade:** truly generative per-activity copy (the
"pourquoi"/questions/reaction lines become model-written) and per-activity
generative imagery. The interfaces (`ContentProvider`, `AdaptiveEngine` question
policy, `RecommendationEngine`) are already the swap points — no refactor needed.

## Part G — Proof + tests

- `flutter analyze` — clean.
- `flutter test` — **112 green** (all prior + new): orb 1:1 tracking; reaction
  labels + controller semantics; LoopController transitions/alternation/
  convergence/select/exhaust (7); on-screen loop integration; LMS mapping (7);
  life-context filters + persistence (9); scorer diversity + serendipity (5);
  content variety + image pick + swappable provider (8); adaptive info-gain pick.
- `flutter build web --release` — OK.

### Visible simulator walkthrough

The deterministic loop is fully driveable on screen (`EngineLoopScreen` with the
`skipReflection` seam; the engine_loop_screen integration test walks
questions → reflection → recommendation). The iOS-simulator screenshot tour
(`s9_mood`, `s9_q1`, `s9_reflect1`, `s9_reco1`, `s9_q2`, `s9_reco2`,
`s9_context_filter`, `s9_select`) reuses the established `VYBIA_PROOF` pattern
(see `tool/` + the S8 screenshots). _See "MVP STATUS" for the exact recipe and
the honest state of the screenshot capture._

---

## Decisions recorded (full autonomy)

1. **No positional lerp existed** — the real orb-lag fix was a frame-rate trim
   (rings 14→9), not removing easing. Locked 1:1 with a test.
2. **LMS motives derived, not stored** — a readout of the latent profile so they
   can't desync; avoids hand-authoring 4 numbers on every catalog entry.
3. **Mood capture stays the Welcome step** (single rich gesture seeding several
   correlated priors); the explicit machine covers the questions↔recos
   alternation. Multi-gesture mood enrichment is a small follow-up.
4. **Old linear screens** (`/discover`, `/intention`, `/profil-pret`, `/reco`)
   kept routable for back-compat/dev; the primary Explorer path is now `/engine`.
5. **Weather** left out of contextFit (no data source); season + time-of-day in.
6. **Serendipity is deterministic** (id/score-seeded), never random — keeps the
   engine pure and the tests stable.

## MVP STATUS (S9)

- **Engine:** loop complete — mood → adaptive batches ↔ reco rounds → Planifier,
  converging, ≤ 3-min feel preserved (tiny batches, skippable reflection).
- **Learning:** latent 8-dim vector + confidence + 4 LMS motives + life-contexts,
  revealed preference correcting declared, persisted across relaunch.
- **Content:** tailored, varied, LLM-swappable; smart per-category vibe imagery.
- **Quality:** analyze clean, 112 tests green, web release builds.
- **Remaining visible proof:** iOS-simulator screenshot tour for the 8 loop
  states. Recipe: add an `EngineLoopScreen` proof-tour gated on
  `--dart-define=VYBIA_PROOF=true` that pins each phase, `flutter run` on the
  booted iOS 26.x sim, `xcrun simctl io booted screenshot ./screenshots/s9_*.png`
  per marker (as in S8's `tool/capture_s8.sh`). Not yet captured — flagged
  honestly, not faked.
