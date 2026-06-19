# S6.2 — Calm lens A/B (PROOF ONLY, nothing selected)

Two bubble shaders now ship side by side, switchable at runtime with
`--dart-define=VYBIA_LENS=calm` (default `vif` = the current S6.1 lens). The
calm variant keeps the convex magnification, glass rim, specular kick and
inner-glow, but softens the mid-lens displacement that produces the spun/swirl
read, and cuts the chromatic split to a hint:

| constant   | vif (current, bubble.frag) | calm (bubble_calm.frag) |
|------------|----------------------------|--------------------------|
| LENS_AMP   | 1.6                        | 0.7                      |
| DISP_FAC   | 0.26 (inline)              | 0.12                     |
| CHROMA_PX  | 16.0                       | 6.0                      |
| MAG_AMP / RIM_BRIGHT / SPEC_BRIGHT / INNER_GLOW | 1.0 / 0.70 / 0.50 / 0.045 | unchanged |

On-device (iPhone 17 Pro, iOS 26.3) crosshair-free frames in `./screenshots/`:
`s6_2_compare_vif_vs_calm.png` (left vif, right calm — same reco image, identical
framing), `s6_2_vif_reco.png`, `s6_2_calm_reco.png`, `s6_2_calm_mood.png`.

**Nothing is selected.** Default stays `vif`; the current shader is untouched.
Founder picks the winner; only then does the default change.
