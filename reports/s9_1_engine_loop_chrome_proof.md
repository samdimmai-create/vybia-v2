# S9.1 — Engine-loop visible proof in Chrome + throw-stop fade

**Status:** complete — all parts committed on `main`, all proofs captured from a
**visible Chrome window** (no iOS simulator). `flutter analyze` clean, **112
tests green**, `flutter build web --release` OK (production build, no proof
defines).

**Machine-constraint decision (permanent for this hardware):** the iOS Simulator
kernel-panics / reboots this fanless MacBook Air (Intel Iris Plus GPU resets —
`SimRenderServer` GPU hang → WindowServer watchdog timeout → reboot, confirmed in
`/Library/Logs/DiagnosticReports`). The S9.1 visible-test TARGET is therefore a
**visible local Chrome window** driven by the in-app programmatic auto-drive and
captured via the DevTools protocol. The iOS-sim proof path is **retired** here.

## Commits

| Part | Commit | Summary |
|------|--------|---------|
| A | `41088be` | Chrome visible-test harness |
| B | `f88c547` | Engine-loop Chrome proof (8 frames) |
| C | `b04eff3` | Throw-stop progressive dissolve |

## PART A — Chrome visible-test harness

Light, leak-free, low-resource-safe.

- **`tool/web_shoot.sh`** — serves `build/web` on a tiny `python3 -m http.server`,
  launches **ONE visible Chrome window** with `--remote-debugging-port` on a
  throwaway `--user-data-dir` (never touches the founder's main Chrome session),
  runs the capture client, and **ALWAYS cleans up** (server + Chrome killed,
  temp profile removed) via an `EXIT/INT/TERM` trap. Portrait window (430×880)
  for the full-bleed scenes. macOS has no `timeout`; the whole lifecycle is
  scoped to one shell invocation so nothing leaks.
- **`tool/cdp_capture.mjs`** — DevTools `Page.captureScreenshot` over the protocol
  (Node 24 built-in `WebSocket` + `fetch`, **zero deps**). Targets the page/tab
  directly (never full-screen `screencapture`, never OS cursor/keyboard). Modes:
  `--once <file>` and marker-synced `--tour --expect a,b,c`.
- Smoke: **`screenshots/s9_1_chrome_smoke.png`** — Accueil renders in Chrome.

The auto-drive runs INSIDE the app at the framework level (programmatic, no
pointer injection), so it works in Chrome with no crosshair.

## PART B — Engine-loop walkthrough in Chrome (the loop is REAL)

New **`S91EngineProofTour`** (`--dart-define=VYBIA_PROOF91=true`, wired in
`app.dart` with the router kept so the Planifier→/plan handoff works) drives the
**real** engine end to end: a real `LoopController` over the real recommendation
engine, real OSM-backed Montréal places, and the **same on-screen
`EngineLoopScreen` rendering** — stepped programmatically, pausing on each phase
and printing `VYBIA_PROOF <name>` markers the CDP client syncs to.

8 frames, in order, showing the engine **changing across rounds**:

| Frame | Content |
|-------|---------|
| `s9_mood.png` | Mood capture — "Comment veux-tu te sentir ?" (Posé / Curieux / Sociable / Plein d'énergie) |
| `s9_q1.png` | 1st adaptive question — "Quel rythme te tente ?" (Tout en douceur / Plein d'élan) |
| `s9_reflect1.png` | Reflection bridge — "Vybia réfléchit… · Humeur · plein d'élan" |
| `s9_reco1.png` | Reco round 1 — **Théâtre du Rideau Vert** · Culture · **à 387 m** · "atmosphère intime" · ★ Meilleur choix · reaction edges Intéressant/Pas intéressant/Plus d'infos/Planifier |
| `s9_q2.png` | 2nd (sharpening) batch targeting the still-uncertain dimension — "Surprise ou valeur sûre ?" (novelty) |
| `s9_reco2.png` | Reco round 2 — **Frite Alors** · Gourmand · **à 248 m** · "une valeur sûre" — **RE-RANKED** (different pick + the *pourquoi* shifted to match the novelty answer) |
| `s9_context_filter.png` | Life-context feasibility — "Avec des enfants" → the Soirée venue is **écarté** (struck-through), café/nature/gourmand/culture **gardé**, via the **real** `LifeContextRules` |
| `s9_select.png` | The decisive Planifier moment on the final reco — loop ends → /plan |

**Proof the loop is real, not staged:** reco1 (Culture · intime) and reco2
(Gourmand · valeur sûre) are genuinely different picks produced by the SAME
driven controller after a sharpening question + a revealed-preference reaction
(anti-repeat + re-rank). Logged each run as `VYBIA_RERANK reco1=… reco2=…`.

### Rendering seams added (default behaviour unchanged)

- `EngineLoopScreen`: optional injected `controller` (caller-owned lifecycle;
  also improves testability) + a `proof` flag.
- `SceneScaffold`: `debugProofFull` — pins the orb at centre with the edge labels
  AND the bottom bubble both at full opacity, so a single screenshot shows the
  options/reaction edges together with the place + "pourquoi" (the normal UX
  cross-fades between them; the live S8.1 behaviour is untouched).
- `WelcomeScreen`: `proofFull` pass-through.

### Capture-timing fix

The first tour run drifted every frame one phase ahead because the capture
client slept the settle delay **inside a serialized chain** (capture N waited for
capture N-1's settle). Fixed: each capture now fires `SETTLE` ms after **its own**
marker independently; only the `shoot()` calls are serialized (no protocol race).
After the fix: **8/8 frames correct**.

## PART C — Throw-stop progressive dissolve (founder add)

A thrown orb that runs out of momentum before reaching an edge now comes to rest
**gracefully** — a fade + scale-down **in place**, right where it stopped.

- **Bug fixed:** on dissolve, `_endThrow` called `_stopFlight()` and the build's
  `pos = _flying ? _flightPos : _current` fell back to `_current` (the *release*
  point), so the painted orb **teleported back to where the finger lifted** and
  faded there — an abrupt vanish. Now `_endThrow` pins `_current` to the flight's
  **rest position** first, so it fades exactly where it stopped.
- **Graceful exit:** a dedicated `_settling` state recedes the orb deeper (scale
  toward a small point) as it fades, over a slightly longer **settle dissolve
  (260 ms)** vs the 150 ms tap/commit dissolve — *quick but graceful*. Durations
  are restored on the next gesture / reset, so taps stay snappy.
- A throw that **does** reach an edge still commits (unchanged).
- Proof: **`screenshots/s9_1_throw_fade.png`** — the orb mid-fade after stopping,
  off-edge, scaled down (`--dart-define=VYBIA_THROWFADE=true` pin on /orb-demo).
- Test: *"a throw that stops mid-scene dissolves — presence → 0, no commit"*
  (`orb_throw_test.dart`) — the pure `ThrowSimulation` dissolve was already
  covered; this asserts the widget-level fade + no-commit.

## How to reproduce (no simulator)

```bash
# Engine-loop walkthrough
flutter build web --release --dart-define=VYBIA_PROOF91=true
tool/web_shoot.sh --tour \
  --expect s9_mood,s9_q1,s9_reflect1,s9_reco1,s9_q2,s9_reco2,s9_context_filter,s9_select \
  --settle 1600 --max-ms 170000

# Throw-stop fade
flutter build web --release --dart-define=VYBIA_THROWFADE=true --dart-define=VYBIA_START=/orb-demo
tool/web_shoot.sh --once s9_1_throw_fade.png --settle 3000
```

## DONE checklist

- [x] `flutter analyze` clean
- [x] `flutter test` green — **112** (111 + the new throw-stop widget test)
- [x] `flutter build web --release` OK (production bundle, no proof defines)
- [x] Chrome smoke + 8 engine-loop frames + throw-fade frame in `./screenshots/`,
      really captured from a visible Chrome window (no simulator, no fake PASS)
- [x] iOS-sim proof path confirmed retired on this machine
