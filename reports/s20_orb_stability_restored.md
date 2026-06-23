# Sprint S20 (URGENT) — Orb stability restored

**Why:** after S17 the founder reported on his iPhone that the orb **freezes /
disappears**, **jitters**, and **choices don't register**. That was a regression
from S17 (the strict near-edge commit gate + the new breathing/specular). The orb
IS the product, so reliability comes before any flourish. Fixed here; the S17
near-edge *visual* is kept, the strict *commit* gate is gone.

**Machine-safe:** no local build/run. `flutter analyze` (0 issues) + `flutter
test` (**221 passing**), shipped via `./tool/deploy.sh` (cloud → iPhone). One
commit per part.

---

## Part A — Reliable choice commit (`S20A`)
**Root cause of "choices don't register":** S17C made a commit require the orb to
be within `kEdgeCommitReach` of the screen edge. A normal thumb swipe releases
mid-screen, so it silently dissolved instead of committing.

**Fix — decouple commit from the proximity visual:**
- `_commitDirection()` now commits on a **deliberate directional drag past the
  travel threshold**, wherever the orb is released — it need not hug the edge
  (this restores the pre-S17 rule).
- `edgeProximityReach` is now **visual-only**: the filter/coloration still bloom
  on approach, but no longer gate whether a choice registers. Removed the
  `kEdgeCommitReach` / `kEdgeIntentMin` commit knobs.

## Part B — No freeze / no disappear (`S20B`)
**Latent hazard:** a commit / double-tap callback can navigate and **dispose** the
orb widget; the code then called `_dissolve.reverse()` on a disposed controller,
which throws mid-pointer-handling and can wedge the gesture → a "frozen" orb.

**Re-hardening:**
- Commit path cancels **all** timers + stops any flight + clears the warning
  **before** firing `onDirection`, then bails if the callback unmounted us before
  touching any controller.
- Double-tap path bails after `onDoubleTap` (back-nav / `maybePop`) if unmounted.
- `_onDown` already fully re-initialises state, so the **next touch always
  restores a fresh, responsive orb** regardless of any prior state; reset still
  fires on pointer-**UP** and pointer-**CANCEL** (the V1 #1-bug guarantee).

## Part C — Smooth tracking, calm orb (`S20C`)
**Jitter source:** S17B added a two-frequency "breathing" shimmer, a drifting
caustic specular, and per-frame `maskFilter.blur` passes — extra work every frame
on a tiny orb, reading as shimmer/stutter on the phone.

**Toned down hard:**
- one slow breath (no second-frequency micro-shimmer);
- drifting caustic specular **removed**;
- per-frame blur passes on the rings + rim **removed** (rings keep a calm opacity
  falloff; rim is static).
- 1:1 tracking is unchanged — position is still hard-assigned to the exact contact
  point every frame, no easing/lerp.

## Part D — Verify + deploy (`S20`)
- `flutter analyze`: **0 issues.** `flutter test`: **221 passing**, including the
  adjusted/added cases in `test/edge_precision_test.dart`:
  - a normal mid-scene directional release **commits** (no edge-hugging needed);
  - a sub-threshold nudge stays a tap;
  - after a commit the orb **dissolves to nothing** (never frozen);
  - **pointer-cancel** resets cleanly (no stuck orb).
- Deployed via `./tool/deploy.sh` (cloud build → GitHub Pages).

### What was reverted / loosened / hardened
| S17 change | S20 disposition |
|---|---|
| Near-edge **commit** gate (`kEdgeCommitReach`) | **Removed** — commit is travel-based again |
| Proximity **reach** drives the visual filter/aura | **Kept** (visual only) |
| Corner gradient (dominant wins) | **Kept** (pure visual) |
| Water transition (splash ⇄ return) | **Kept** — audited, doesn't touch the orb state machine |
| Two-frequency breathing | **Reverted** to one slow breath |
| Drifting caustic specular | **Removed** |
| Per-frame ring/rim blur | **Removed** |

### For the founder — open on iPhone
The orb should now **follow smoothly**, **never freeze or disappear**, and **every
deliberate swipe registers a choice** — no need to drag all the way to the edge.
The decisive colour still grows as you head toward an edge, and corners still
blend two colours; only the *reliability* changed, not the look.
