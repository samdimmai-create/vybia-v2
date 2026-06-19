# Sprint S4 / S4B — Planifier + Mes Plans + Edge Decisive-Color System

**Status: PASS** (analyze clean · `flutter test` 25 green · `flutter build web --release` OK)

## Step A — Planifier + Mes Plans (all-orb)

- **Plan model** (`features/plans/model/plan.dart`): activity + `PlanMoment`
  (Maintenant / Ce soir / Ce week-end / Choisir une date) + `PlanCompanions`
  (Solo / En couple / Entre amis / En famille); `when` drives Futurs/Passés split.
- **PlanController + PlanScope** (session store above the navigator; seeds 2 past
  plans so Passés reads as real). `create` / `update` / `remove`, Futurs/Passés getters.
- **Planifier flow** (`planifier_screen.dart`): replaces the S3 stub. Orb-driven
  Quand ? → Avec qui ? → confirm; low friction (3 swipes). Supports edit (Modifier).
  On confirm it saves and lands on Mes Plans with the new plan heading Futurs.
- **Mes Plans** (`mes_plans_screen.dart`): scrollable Futurs/Passés universal-bubble
  cards; tapping opens an immersive selected-plan orb layer —
  **up Détails · down Modifier · left Partager (transient toast) · right Supprimer
  (session removal)** — plus a Détails panel and a close affordance.
- **Wiring**: reco down → Planifier; Intention down → Mes Plans; `/mes-plans` route;
  `/dev` entry.
- **Tests** (`test/plan_controller_test.dart`): create→Futurs, supprimer removes,
  modifier updates in place, pickDate honoured, notifies, seeded Passés.

## Step B — Edge Decisive-Color System (reusable, every orb scene)

- **`EdgeAction`** colours by ACTION MEANING, not direction: joy = warm gold,
  reject = desaturate→grayscale + darken, curious = indigo, go = green,
  neutral = sea-glass.
- **`VybiaOrb.onAim`** streams a live `OrbAim` (aimed direction + `reach` 0→1).
- **`EdgeDecisiveOverlay`** (shared, dropped into `SceneScaffold`): as the orb nears
  a decisive edge it filters the image *from that edge* — 0 at centre, intense near
  the edge, scaling with `reach`. `reject` uses a real `BackdropFilter`
  grayscale+darken masked from the edge. The orb's aura recolours toward the action
  colour (or darkens for reject). Only fires for edges that are real choices; paints
  nothing when idle (≈free at rest, 60fps).
- **Wired meanings**: reco (J'aime joy / Pas pour moi reject / Plus d'infos curious /
  Planifier go); Mes Plans selected (Détails curious / Modifier go / Partager joy /
  Supprimer reject); Planifier confirm (Confirmer go).

## Visible test

- **Target = iOS Simulator (required) — could NOT build/run on this machine.**
  Xcode 26.3 exposes **no eligible iOS-18.3 simulator run destination** (only the
  uninstalled iOS-26.2 runtime is offered); `flutter drive -d <ios-sim>` fails with
  *"iOS 26.2 is not installed."* Installing the iOS-26.2 simulator runtime is a
  multi-GB Xcode-GUI download (Settings ▸ Components) that can't be done autonomously.
  Additionally, the visible-test rules forbid injected gestures, so the orb-held
  edge-filter states (the essence of Step B) can't be shown on the simulator anyway.
- **Fallback = visible Chrome** (per the brief). Full S4 flow walked and captured:
  reco → Planifier (Quand ? → Avec qui ? → confirm) → Mes Plans (new plan in Futurs)
  → selected-plan layer → Détails → Partager (stays) → Supprimer (removes + toast).
- **Step B proof**: live held-orb states couldn't be injected through the browser
  (JS PointerEvents don't reach Flutter's gesture layer; the MCP drag releases before
  capture), so a deterministic `/dev` route **`/edge-demo`** renders the overlay at
  fixed aims — witnessing all four action colours and the reach-based intensification.

### Screenshots (`./screenshots/`)
- `01_reco.png`, `02_planifier_moment.png`, `03_mes_plans.png` (headless web)
- `edge_decisive_demo.png` (Step B colour + intensity proof)
- Live flow states (welcome, planifier companions/confirm, selected layer, Détails,
  Supprimer toast) captured inline during the Chrome walk.

## Autonomous decisions
- Project was web-only → scaffolded `ios/` (kept, for the required target) and a
  temporary `macos/` (removed — `integration_test` can't screenshot on desktop).
- Added an app-level `navigatorKey` + `integration_test` harness for deterministic
  framework-level driving (no OS cursor).
- Planifier moment/companions steps are neutral selections → neutral brand tint;
  only the confirm commit uses `go` (green). Noted as a deliberate choice.
- Added `/edge-demo` dev route as the deterministic Step B visual witness.
