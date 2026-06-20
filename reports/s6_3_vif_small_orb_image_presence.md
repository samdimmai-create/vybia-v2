# S6.3 — vif lens default, V1-size orb, image presence restored

Founder decision implemented: keep the **vif** liquid-glass lens as the shipped
look, shrink the refracting bubble to a **V1-size jewel**, and let the
illustrative image read as the hero — touched only by (a) the local refraction
under the moving orb and (b) the subtle growing decisive-edge filter.

## What changed (3-line core)
1. **vif is the only lens.** Dropped the S6.2 calm A/B path: removed the
   `VYBIA_LENS` dart-define switch in `refraction_bubble.dart` (now a single
   `const _shaderAsset = 'assets/shaders/bubble.frag'`), deleted
   `assets/shaders/bubble_calm.frag`, and removed it from `pubspec.yaml`.
2. **V1-size orb.** `SceneScaffold.lensRadius` default **108 → 60**
   (ø ~216 → ~120 px). Vif shader retuned for the smaller bead: `CHROMA_PX`
   **16 → 9** (the only absolute-pixel constant; LENS_AMP 1.6 / MAG_AMP 1.0 /
   RIM_BRIGHT 0.70 / SPEC_BRIGHT 0.50 / INNER_GLOW 0.045 are radius-relative and
   read identically at the new size). `magnification` stays 0.8.
3. **Image presence restored.** `SceneScaffold._ambient` **0.5 → 0.0** — there is
   no always-on drifting lens anymore, so at rest the image is fully present; the
   bubble is born under the finger on contact and melts on release. The top
   legibility scrim was softened **0.72 → 0.55** alpha and is the only remaining
   image overlay (tight, local to the headline, which also carries its own text
   shadow). The decisive-edge filter (`EdgeDecisiveOverlay`) is unchanged and
   still paints nothing at idle.

## Polish
- `/profil` overlap fix: the Aperçu `_LearnedCard` bottom padding raised
  `huge → huge + xxl` (64 → 112) so the last recap row (Ambiance / feutré) sits
  clear above the SceneScaffold "Touche, glisse…" hint chip — no overlap.

## Verification
- `flutter analyze` clean (no issues).
- `flutter test` green — 37/37, including the EdgeDecisiveOverlay idle-no-paint
  test and the RefractionBubble null-orb (lens hidden) test.
- Fresh iOS-simulator frames (iPhone 17 Pro, iOS 26.3), programmatic auto-drive
  → crosshair-free, in `./screenshots/`:
  - `s6_3_rest.png` — no orb: image at full presence (headline test).
  - `s6_3_reco_joy.png` / `_reject.png` / `_go.png` / `_curious.png` — small
    V1-size jewel + the growing edge colour at each decisive edge
    (joy=amber, reject=grayscale drain, go=sea-glass green, curious=lavender).
  - `s6_3_mood.png`, `s6_3_profil.png` — small orb on those images; image hero;
    profil shows no hint/card overlap.
  - `s6_3_compare_size.png` — AVANT big lens (r=108) vs APRÈS V1 jewel (r=60) on
    the same reco image; the ~2× size drop (and brighter image) is obvious.

## Decisions
- Calm variant dropped entirely (not left behind a dead flag) to keep the
  shader/loader path tidy — vif is the single shipped lens.
- At-rest ambient lens removed rather than merely reduced, to honour "image is
  the hero, influenced by only two things"; the brand bubble identity is now a
  contact/decision effect, not a constant veil.
- Capture harness: `scripts/s63_capture.sh` + `scripts/s63_poll.sh` land on one
  route via `VYBIA_START` and snap each drive state on its 2nd marker (decode
  warmup skip); `scripts/s63_compare.py` (Pillow) composes the side-by-side.

OSM data + geolocation are S7 — not started.
