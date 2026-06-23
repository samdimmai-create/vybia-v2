# S22 — Effect finitions (orb edge effects) + transparent water

**Workspace:** `~/Desktop/vybia-v2`
**Machine-safe:** no `flutter run` / `flutter build` / iOS sim / Chrome-on-Mac. Validated
with `flutter analyze` (clean) + `flutter test` (229 passed). Built + verified in the cloud
on push; final visual check on the founder's iPhone.

This sprint did not touch S18/S19 scope. It fixes the remaining EFFECT issues the founder
saw on his iPhone after S21 (where the orb itself glides 1:1 and commits only on a
deliberate swipe — that feel is preserved).

---

## PART A — edge effect starts only near the edge (short distance)
`commit "S22A: tighter edge-proximity zone"`

- **`kEdgeZoneFrac` 0.42 → 0.18** (named tunable, `lib/components/orb/vybia_orb.dart`).
- At 0.42 the decisive filter + orb coloration ramped on from ~42% of the way in, so the
  effect painted across most of the scene. At **0.18** the whole middle of the image is
  **clean** and the bloom only begins in a short near-edge band (~18% of the shorter side),
  reaching full intensity right at the edge.
- The COMMIT is unchanged — it stays travel-based (S20A), independent of this zone; A only
  governs where the *visual* intensifies.
- Tests updated to the new band (`test/edge_precision_test.dart`).

## PART B — restore the edge effect where it vanished
`commit "S22B: edge effect back on Accueil + all orb scenes"`

- **Root cause:** the S21 refactor moved the decisive overlay into `SceneScaffold`. The
  **Accueil** hub drives the orb *directly* (not via `SceneScaffold`), so it was left with
  **no `EdgeDecisiveOverlay` at all** — the orb coloration + gradient filter were simply
  absent on the home screen.
- **Fix (`accueil_screen.dart`):** converted to a stateful screen that wires the orb's live
  `onAim` / `onPositionChanged` into an `EdgeDecisiveOverlay` over the calm field, with one
  decisive action per hub direction — Explorer = curious (blue), Planifier = go (green),
  Mon profil = joy (champagne), Mes plans = neutral (cyan). Edge labels glow in the same
  hue as the wave they trigger, palette-aware. Same repaint-isolated `ValueNotifier` pattern
  as `SceneScaffold` (no per-move setState).
- **Audit of every other orb scene:** all guest/structural scenes (welcome, discover, reco,
  plan, profil, mes-plans) go through `SceneScaffold`, whose `onAim → _aim → EdgeDecisiveOverlay`
  wiring is intact — no regression there. The `intention` hub used uniform `neutral` actions,
  so its effect read flat; it now uses the same four distinct hub hues as Accueil.

## PART C — visible orb travel on a flick
`commit "S22C: visible flight to edge on flick"`

- **Root cause:** a deliberate flick that also traveled past the commit threshold hit the
  instant-commit path and fired `onDirection` immediately — the orb never *flew*. Only
  sub-threshold flicks ever showed a (ballistic) flight.
- **Fix (`vybia_orb.dart`):** on release, if the gesture is a **flick** (release velocity ≥
  `throwVelocity`) *and* names a clear cardinal direction, the orb now performs a **directed
  commit glide** — it lerps visibly from the release point to the target edge (duration scales
  with distance, 160–340 ms, eased), the decisive wave + coloration intensifying as it
  arrives, and only THEN commits. A directed glide (not the ballistic sim) so it **always
  reaches the edge** and the choice can never stall mid-scene.
- A slow drag-past-threshold still commits at once (nothing to fly — the orb is already where
  the finger left it). A sub-threshold flick that names no clear cardinal still does a
  ballistic throw (may dissolve). Glide is aborted cleanly by a fresh touch / reset.

## PART D — corner gradient every time
`commit "S22D: reliable corner blend"`

- **Root cause:** `cornerBlend` required the *perpendicular* edge to have its own proximity
  reach. With the tighter S22A zone the orb is almost never near both edges at once, so the
  blend returned ~0 nearly always → "pas toujours".
- **Fix:** the blend is now driven by the **aim's diagonal-ness** (`diagRatio = minor/major`),
  gated only by the dominant edge being in its active band — no perpendicular-proximity
  requirement. A `0.5·√diagRatio` floor lifts even a moderate diagonal to a clearly visible
  two-edge gradient; a perfect 45° still caps at the even 0.5 (dominant edge keeps the
  majority). The committed choice still goes to the dominant edge. Signature simplified to
  `cornerBlend(primaryReach, diagRatio)`; tests rewritten.

## PART E — water effect must be transparent (see-through)
`commit "S22E: translucent water/ice reveal"`

- **Root cause:** `WaterReveal` clipped an **opaque** `CalmHomeField` disc over the scene plus
  a flat aqua veil — "pas transparent du tout".
- **Fix (`water_transition.dart`):** the rising disc is now a **translucent** aqua/glass body
  (`_TranslucentWaterPainter`: a see-through radial tint, clearer at the centre, deepening
  toward the surface, with a soft glassy sheen band) painted over whatever is beneath — so the
  image **stays visible through the rising water**. The solid calm field is faded in only over
  the last stretch (`fieldOpacity = (eased − 0.45)/0.55`), so the photo shows through for most
  of the dissolve and the screen still fully opens onto the calm Accueil at progress 1. The
  signature wavefront crests are unchanged. Shared by both the splash and the hold-to-home
  return, so both read the same.

## PART F — validation
- `flutter analyze` → **No issues found**.
- `flutter test` → **229 passed** (incl. edge_precision, edge_decisive, orb_throw,
  orb_interaction, accueil_hold_home).
- No local heavy build (machine-safe). Deploy via `./tool/deploy.sh` → cloud build → Pages URL.

### Founder verification on iPhone
1. **Near-edge only:** mid-scene the image is clean; colour blooms only as the orb approaches an edge.
2. **Present everywhere incl. Accueil:** the home screen now colours/filters per direction.
3. **Visible flight:** a flick visibly flies the orb to the edge before the choice commits.
4. **Corners always blend:** any diagonal aim shows both nearby edges' colours.
5. **See-through water:** on a hold-to-home return the scene stays visible under the rising
   transparent water until it fully opens the Accueil.
