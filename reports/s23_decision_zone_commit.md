# S23 — Decision of the orb: a precise, controllable decision zone

**Workspace:** `~/Desktop/vybia-v2`
**Machine-safe:** no `flutter run` / `flutter build` / iOS sim / Chrome-on-Mac. Validated
with `flutter analyze` (clean) + `flutter test` (**264 passed**). Built + verified in the
cloud on push; final visual check on the founder's iPhone.
**Theme / orb look unchanged** — only the COMMIT trigger changed (plus one additive cue).
Live URL (open on iPhone): **https://samdimmai-create.github.io/vybia-v2/**

---

## The problem the founder felt

On iPhone the orb's decision was *"pas précise, pas toujours contrôlable, décide AVANT
d'atteindre la zone de décision (parfois même au centre)."*

**Root cause:** S18 (an out-of-context session) re-loosened the commit to be
TRAVEL/VELOCITY-based — a release committed as soon as the drag had travelled a short
distance from where the orb was born (`threshold` 56 px), with one axis dominant
(`kAxisDominance` 1.12). Because it measured **distance from the birth point**, not the
orb's **position**, a brief swipe fired a choice *anywhere* — including near the centre.
That regressed the founder's S22 5/5.

## The model now: a DECISION ZONE

A choice commits **only when the orb's POSITION reaches a band near the chosen edge** —
the *decision zone*. Never at the centre, never mid-drag before the zone. The user guides
the orb toward an edge, sees the effect grow on approach, and the choice fires when (and
only when) the orb **enters the zone**. Release before the zone = **no commit** (the orb
glides back to rest). The same rule governs a drag and a flick.

---

## PART A — position/zone-based commit  ·  `commit "S23A: decision-zone commit"`

**The decision zone** (`lib/components/orb/orb_throw.dart`)
- New tunable `kDecisionZoneFrac = 0.22` — the outer **22 %** of the relevant axis toward
  the edge (width for left/right, height for up/down). Larger = the zone reaches further
  inward (easier, less precise); smaller = you must guide the orb closer to the edge (more
  precise, more deliberate). 0.22 is reachable with a thumb yet unmistakably near the edge.
- New pure helper `inDecisionZone(bounds, edge, pos, zoneFrac)` — is the position inside
  that edge's band? The whole centre of the scene is outside every zone.

**The drag commit** (`lib/components/orb/vybia_orb.dart`)
- `dominantEdge(delta)` — the clear cardinal **direction** of a drag (one axis beats the
  other by `kAxisDominance`, past a small birth deadzone). **No travel-to-commit gate.**
- `zoneCommit(bounds, pos, delta)` — commits an edge **only when** `dominantEdge` names it
  **AND** `inDecisionZone` is true for the orb's current position. This is the new
  `_commitDirection()`.
- **Removed (the S18 regression):** the travel-from-origin commit
  (`deliberateCommit(delta, travel: threshold)`). The `threshold` (56 px) and the throw's
  old `edgeMargin` (52 px) no longer gate any choice; `threshold` is kept only so the
  public constructor signature is unchanged and is marked vestigial.

**Threshold cue / feedback**
- The validated S22A approach bloom (edge effect + orb coloration growing on approach) is
  **kept exactly** — `kEdgeZoneFrac` and the painter's existing layers are untouched.
- Added one **additive** cue: `OrbAim.inZone` is true the moment a release would commit,
  and the orb paints a single crisp pearl **decision ring** while in the zone
  (`orb_painter.dart`). It is drawn **only inside the zone**, so everywhere else the orb is
  byte-identical to the validated S22 orb — the approach look cannot regress. The ring is
  the unmistakable "you've entered the decision zone" signal; its **absence** confirms you
  can still stop short and release safely.

## PART B — flick carries the orb into the zone  ·  `commit "S23B: flick reaches the zone"`

- `ThrowSimulation` (the visible ballistic glide) now commits the moment the orb's
  **position enters the decision zone** of the edge it is heading into (`inDecisionZone`),
  instead of within `edgeMargin` of the very edge. Its `zoneFrac` defaults to
  `kDecisionZoneFrac`.
- So a deliberate flick rides its visible glide into the zone and commits there; a **weak
  flick stops short of the zone and dissolves** (glides to rest, no commit) — exactly the
  same rule as a drag.
- **Retired the S22C directed commit-glide.** That path was a lerp that *always* reached
  the edge, so it could never represent "a weak flick stops short = no commit." Flicks now
  route through the zone-gated ballistic glide (which is itself the visible flight). On
  release: if the orb is already inside the zone → commit at once; otherwise, if it's a
  flick → throw it and let it commit on reaching the zone (else dissolve); otherwise it's a
  tap / glide back to rest.

## PART C — tests + deploy  ·  `commit "S23: precise controllable decision"`

- `flutter analyze`: **clean.** `flutter test`: **264 passed.**
- New / updated pure tests (`test/edge_precision_test.dart`):
  `dominantEdge` (direction only), `inDecisionZone` (centre is outside every zone; near an
  edge is inside; just short is not), `zoneCommit` (reached-the-zone commits; short of the
  zone / at the centre / ambiguous ~45° → no commit).
- New / updated widget tests: a drag that **reaches** the zone commits; a **mid-scene**
  release does **not** commit; a release back at the **centre** never commits.
- New / updated flick tests (`test/orb_throw_test.dart`): a strong flick reaches the zone
  and commits; a **moderate** flick commits at the zone even though it would stop short of
  the very edge; a **weak** flick stops short and dissolves.
- Shared `swipe` helper in `test/plan_recap_test.dart` updated to drag fully into the zone
  (the app-flow tests assert the new precise contract).
- Deployed via `./tool/deploy.sh` (cloud build → GitHub Pages).

---

## What to verify on your iPhone

1. **Nothing commits at the centre** or before the zone — you can move the orb around the
   middle of the image and release with no choice firing.
2. A choice triggers **precisely when the orb reaches the near-edge decision zone** — watch
   for the pearl **decision ring**: it appears exactly as you enter the zone, and a release
   then (or the moment you cross in) commits.
3. You can **guide the orb in and stop short safely** — release before the ring appears and
   the orb glides back to rest, no choice.
4. A **flick visibly glides** toward the aimed edge and commits when it **reaches the
   zone**; a **weak flick** that stops before the zone makes **no** choice.

## Tuning knob

If the zone feels too far in or too shallow, change one constant —
`kDecisionZoneFrac` in `lib/components/orb/orb_throw.dart` (currently `0.22`). Higher =
the choice fires sooner / further from the edge; lower = you must guide closer to the edge.
