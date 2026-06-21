# S11 — Research-grounded deterministic scoring

**Goal.** Before any LLM is plugged in, make the autonomous engine as smart as it
can be: analyze preferences and produce genuinely good, explainable
recommendations on its own, grounded in the leisure / wellbeing research. No LLM,
no runtime network in the deterministic brain. Commit per part.

**Status.** Implemented A→E. `flutter analyze` clean · `flutter test` 165 green ·
`flutter build web --release` OK · 4 Chrome proof frames captured (visible Chrome,
no simulator). Branch `main`, commits:

| Part | Commit | What |
|---|---|---|
| A | `c59b765` | hedonic↔eudaimonic axis + happiness-trait tagging |
| B | `bb9aa57` | research-grounded named/weighted scorer |
| C | `1516538` | context feasibility filters (weather seam) |
| D | `44639e9` | diversity, serendipity, explainable factor breakdown |
| E | _this commit_ | proof tour + report |

---

## Research doctrine → where it lives in code

| Principle (source) | Encoded as |
|---|---|
| **Leisure Motivation Scale** — 4 motives: intellectual, social, competence-mastery, stimulus-avoidance (Beard & Ragheb 1983) | `LeisureMotivation` (S9C) → `w_motive` term; the guest's weights are a readout of the live profile + mood, each activity's affinity from its axes/category. |
| **Hedonic vs eudaimonic wellbeing** (Ryan & Deci 2001; Huta & Ryan 2010) | `WellbeingTags.hedoniaEudaimonia` (S11A) + the `w_affect` term: match the activity's axis to the guest's *current* desired position (escape→hedonic, curiosity→eudaimonic). |
| **Context-aware / affective rec systems** (Adomavicius & Tuzhilin) | `RecoContext` (time, season, **weather** S11C, location) used BOTH as hard feasibility filters AND soft fit (`w_context`, `w_proximity`). |
| **Novelty → hedonic boost; serendipity → life satisfaction** | `w_novelty` scaled to the guest's own novelty preference + one DOSED, deterministic serendipitous pick (S9E). |
| **Revealed > declared preference; affective forecasting** | The profile is continuously nudged by Intéressant/Pas-intéressant reactions (`RecoController`), so `prefMatch` is revealed-corrected; confidence-weighting leans on what we actually know; anti-repetition via `excludedIds` + `w_repeat`. |
| **Choice overload** (Iyengar & Lepper 2000) | 4–6 recommendations, best first, one at a time. |
| **Happiness-raising activity traits**: self-congruent, intrinsically appealing, flexible, socially supported (Lyubomirsky positive-activity model) | `WellbeingTags` social-support / intrinsic-appeal / flexibility (S11A) + the `w_happiness` term (S11B). |

---

## A — Activity enrichment (hedonic/eudaimonic + happiness + motive)

Every activity now carries **research-grounded wellbeing tags**, derived
deterministically (a *readout* of data it already has — no hand-authoring on 20
seed + 200+ DB rows, and they can never drift):

- `hedoniaEudaimonia` ∈ [0,1] — 0 hedonic (pleasure/escape) … 1 eudaimonic
  (meaning/growth). From `motive` affinities (eudaimonic↑, hedonic+relaxation↓) +
  a category bias (culture/creative eudaimonic; café/nightlife hedonic).
- `socialSupport`, `intrinsicAppeal`, `flexibility` — the happiness-raising
  traits, from social/vibe axes, motive, budget, effort, availability + category.

`WellbeingTagger.of(activity)` is the single source of truth; a `CatalogEntry`
(S10 schema) may PERSIST an override (lossless JSON round-trip, denormalised into
`llmSlice`) — the seam a future Claude enrichment writes back through. The 4
Beard & Ragheb motive affinities were already tagged at runtime (S9C).

## B — The scoring model

A clear, named, weighted, tunable blend. Each term names its principle; each
weight is a named constant with a one-line rationale in
`recommendation_engine.dart`:

```
score = w_pref·prefMatch(confidence-weighted, revealed-corrected)   // 0.30
      + w_motive·lmsMotiveMatch          (Beard & Ragheb LMS)         // 0.16
      + w_affect·hedonicEudaimonicMoodFit (Ryan&Deci / Huta&Ryan)     // 0.14  ← NEW
      + w_context·contextFit(timeOfDay, season)                       // 0.10
      + w_social·socialFit                                            // 0.06
      + w_novelty·(noveltyPref · activityNovelty)  (novelty→hedonic)  // 0.08
      + w_happiness·happinessTraitFit    (Lyubomirsky)                // 0.10  ← NEW
      + w_proximity·(1 − farness)        (reachability as soft fit)   // 0.10
      − w_repeat·repetitionPenalty       (revealed-pref anti-repeat)  // 0.06
```

- **Confidence-weighting:** each taste axis contributes `weight = 0.2 +
  confidence`, so low-confidence dimensions barely count — the engine leans on
  what it actually knows.
- **`w_affect` (new):** the guest's desired hedonic↔eudaimonic position is read
  off their live LMS weights (`intellectual + 0.6·competence` pulls eudaimonic;
  `stimulusAvoidance + 0.4·social` pulls hedonic). Fit = `1 − |activityHE −
  desiredHE|`. This is what flips the pick by mood/motive on the SAME catalog.
- **`w_happiness` (new):** self-congruent social support (`1 − |support −
  guestSocial|`) + intrinsic appeal + flexibility.
- Every pick keeps a transparent `ScoreBreakdown` of the weighted per-term
  contributions — used for ranking, explainability AND the unit tests.

## C — Context-aware feasibility (hard filters)

Before ranking, the INFEASIBLE are hard-filtered:

- **Life-contexts** (S9D): kids→no nightlife/late, sans-alcool→no bars,
  budget→no splurge, mobilité→low-effort/near, sans-voiture→nothing far,
  animal→pet-ok indoors.
- **Distance / reachability**: too-far dropped; a confident "nearby" tightens it.
- **Weather (S11C, new):** wet (rain/snow) → no open-air; deep cold → no
  non-winter-friendly outdoors. **Only when a weather signal is injected** —
  with no signal (the default, since the deterministic brain runs no network)
  the weather filter is skipped: a noted seam, wire a free weather source in to
  switch it on.
- **Starve-guard:** if a context pile-up would leave < 4 options, fall back to
  the unfiltered pool — never show nothing.

## D — Ranking: diversity + serendipity + explainability

- **Diversity-aware** (S9E): category spread + near-duplicate-venue guard so the
  4–6 aren't all alike.
- **Dosed serendipity** (S9E): one guaranteed high-novelty discovery among the
  alternatives unless the guest is confidently novelty-averse — deterministic
  (id/score-seeded), never replacing the genuine best pick.
- **Explainability (S11D, new):** each recommendation exposes its **top
  contributing factors** as short French chips (e.g. `motif : évasion · tout
  près · nouveau pour toi`), built from the *real* `ScoreBreakdown` — strongest
  terms first, deduped, capped at 3, never a reason that didn't move the score.
  Surfaced in the "Pourquoi pour toi" detail block. This is also the seam a
  generative "pourquoi" would consume.

## E — Proof + report

Visible-Chrome proof (`--dart-define=VYBIA_PROOF11=true`, `tool/web_shoot.sh`),
in `./screenshots/`:

| Frame | Proves |
|---|---|
| `s11_tired_escape.png` | tired/escape mood → **Java U Café**, *hédonique*, "pour souffler · tout près · motif : évasion" |
| `s11_curious_growth.png` | curious mood → **Le Studio TD** (culture), *eudémonique*, "ça a du sens" — SAME catalog, different top pick |
| `s11_context_filter.png` | rain + avec-enfants → only interior picks survive the hard-filter |
| `s11_explain.png` | the per-term weighted bar breakdown + factor chips behind one "pourquoi" |

Tests added (`flutter test` 165 green):
`wellbeing_tagger_test` (6), `scorer_research_grounded_test` (7 — affect flips the
pick both ways, breakdown.total==score, affect moves between guests,
confidence-weighting), `context_feasibility_test` (6 — no-signal seam, wet/cold
filter, clear keeps outdoor, starve-guard, life-context), `reco_factors_test`
(5 — honest factors, escape vs discovery flavours, determinism, no duplicates).
Prior scorer/serendipity suites still green.

---

## What Claude would still add vs what is now well-handled autonomously

**Now well-handled deterministically (no LLM needed):**
- Preference analysis + ranking grounded in the research, with confidence- and
  revealed-correction.
- Mood/motive-driven differentiation (hedonic vs eudaimonic) on one catalog.
- Context + weather + life-context feasibility, diversity, dosed serendipity.
- An honest, specific, factor-level "pourquoi" — already presentable.

**Where Claude is the genuine upgrade (the seams are in place):**
- **Generative copy:** truly per-activity, voiced "pourquoi" + descriptions,
  beyond the templated fragments — slots behind `ContentProvider`, fed by the
  ordered `ScoreBreakdown` factors (no engine change).
- **Catalog enrichment:** fill description gaps, infer life-context flags,
  author the persisted `wellbeing` override — through the existing
  `EnrichmentService` write-back path (`CatalogEntry.llmSlice` → upsert).
- **Open-ended understanding:** free-text intent ("something to forget a rough
  week") mapped to the profile/contexts the deterministic engine already scores.
- **Live world knowledge:** events/films/availability — the `LiveSource` seam
  (S10.1); deterministic snapshot remains the offline fallback.

The deterministic engine is now a strong floor on its own; Claude raises the
ceiling on language and world-knowledge, not on the core reasoning.
