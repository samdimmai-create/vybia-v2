# Sprint S21 — Orb feel + Accueil routing + corner gradient + water effect

**Workspace:** `~/Desktop/vybia-v2` · machine-safe (no local heavy build — code →
cloud → iPhone). `flutter analyze` clean across the project; `flutter test`
227/227 green.

The orb IS the product and had missed twice (S17 over-strict, S20 over-loose).
This sprint fixes the FEEL with a real latency diagnosis + a provably-direct
pointer→paint path and a provably deliberate-only commit, then restores the
Accueil-always landing and makes the corner gradient + water effect actually
visible.

---

## PART A — Orb feel (CRITICAL) · commit `S21A`

### Diagnosis (root cause, not a constant tweak)
Every pointer-move fired **three** `setState` rebuilds of the whole scene tree:
one in `VybiaOrb._onMove` and **two** in `SceneScaffold` (`onPositionChanged` +
`onAim`). That full-tree rebuild re-ran the heavy **9-ring refraction lens**, the
decisive overlay, the bubble, the labels and the journey indicator on **every
move**. On Flutter web that per-move rebuild is exactly what made the orb feel
**heavy** and **trail** behind the finger — the "heavy" feel WAS the latency.

### The fix — make pointer→position→paint provably direct
- **`VybiaOrb._onMove` no longer calls `setState`.** The raw pointer value is
  hard-assigned (`_current = e.localPosition`) and the orb body repaints on the
  always-running `_pulse` ticker (its `AnimatedBuilder` re-reads `_current`).
  Position is now **frame-coalesced and 1:1** with no rebuild churn between
  pointer and paint. (The S9.0 "tracks the finger 1:1" test still passes.)
- **`SceneScaffold` drives orb / aim / presence / hold through `ValueNotifier`s,
  not `setState`.** Each visual layer is a `RepaintBoundary`-wrapped builder
  listening to the **minimal** notifier it needs:
  - lens + decisive overlay → `_orb` / `_aim` (repaint on move),
  - labels / bubble / journey → `_presence` (rebuild only on birth/dissolve),
  - water → `_hold`.
  A plain move now repaints **only the lens + overlay**; everything else stays
  put. Also dropped the 8 s idle Lissajous ticker that rebuilt the whole scene at
  60 fps even at rest (ambient lens strength is 0, so it was invisible work).

### Deliberate-only commit (no more involuntary choices)
New `deliberateCommit(delta, travel, dominance)` pure rule: a release commits a
direction only when the drag is an **unmistakable cardinal swipe** —

- travel ≥ `threshold` (72 px), **AND**
- one axis clearly dominates: `major ≥ kAxisDominance(1.25) × minor` (≈ within
  ~38° of an axis).

So an **ambiguous ~45° drift** or a **slow nudge dissolves** — it never commits.
A strong diagonal still commits its clearly-dominant axis (corner behaviour
preserved). The throw/flick velocity was raised **720 → 900 px/s** so a relaxed
lift no longer flings a commit. The live *preview* tint stays loose (14 px
deadzone) — only the COMMIT tightened, which is the tuned middle ground.

### Tests added (the commit rule)
- pure: clear swipe commits; sub-travel nudge does not; ambiguous ~45° does not
  (however far it travels); strong diagonal still commits its dominant axis.
- widget: an ambiguous ~45° release fires **no** `onDirection`.

---

## PART B — Splash → Accueil routing · commit `S21B`

Reverted S16's "first-visit skips the hub". After the splash, **every** visit
(first or returning) now lands on the calm **Accueil** hub, from which the orb
offers `← Explorer · → Planifier · ↑ Mon profil · ↓ Mes plans` (the mapping was
already correct in `AccueilScreen`). Value stays one swipe away via Explorer,
but the hub is never bypassed. Removed the now-dead `GuestScope` import; the
routing widget test now asserts the hub for **both** new and returning guests.

---

## PART C — Corner two-edge gradient · commit `S21C` (+ orb-file part in `S21A`)

The corner gradient "didn't work" because the old single wave **averaged** the
two edge colours into one muddied lerp, weighted so low it was invisible. Now,
near a corner, the decisive overlay flows **both** edges' waves in — the
dominant edge's pure colour from its edge **and** the perpendicular edge's pure
colour from **its** edge — so the corner reads as a real **gradient of two hues
meeting**. The secondary edge *direction* is threaded through the overlay +
painter to anchor that second wave; the orb's own aura/hotspot leans toward the
blend (`OrbPainter` already lerps). Detection fires earlier
(`perpendicularEdge` minorFrac 0.18→0.12) and the blend weight uses a visible
floor curve (`0.45 + 0.55·diagRatio`). A clean cardinal swipe has no secondary
edge ⇒ stays pure. The commit still goes to the dominant axis.

---

## PART D — Water/ice wave reveal · commit `S21D`

The shared `WaterReveal` (SPLASH **and** hold-to-home RETURN) was barely
perceptible — a single faint crest over the calm field read as nothing. It now
shows a clear-but-calm **rising surface**: a deep aqua "underwater" band behind
the advancing crest (visible submersion depth), a small train of soft blurred
pearl **ripple crests** so the rise reads as waves, a stronger chromatic
cyan/champagne split on the surface, and a deepened submersion veil (0.10→0.16).
Same widget for both moments, so launch and return remain one coherent brand
gesture — kept wide/blurred/low-contrast (calm, never aggressive).

---

## PART E — Validation + deploy

- `flutter analyze` → **No issues found** (whole project).
- `flutter test` → **227/227 passing** (incl. the new commit-rule + corner +
  routing assertions; the 1:1-tracking and rest/contact scene tests still pass,
  confirming the latency refactor preserved behaviour).
- No local heavy build (machine-safe). Deployed via `./tool/deploy.sh` (cloud
  build → GitHub Pages).

### Founder — open the live URL on your iPHONE and check:
1. The orb **glides under the finger** with no trail (touch + drag around).
2. **Only a deliberate swipe** chooses — a slow/ambiguous drift just dissolves,
   no accidental choice.
3. The **splash lands on Accueil** every time; Explorer is one swipe left.
4. Near a **corner**, the filter + orb show a **blend of the two edges' colours**.
5. The **water effect** clearly invades/submerges the image on splash AND on
   hold-to-home return.

(Untouched: S18/S19 scope.)
