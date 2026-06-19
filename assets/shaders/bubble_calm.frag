#version 460 core
#include <flutter/runtime_effect.glsl>

// Vybia "liquid-glass bubble" — S6.2 CALM variant (A/B proof, not yet default).
//
// Same liquid-glass anatomy as bubble.frag (the "vif" lens), but tuned for a
// CALM, premium Apple-style convex magnifier instead of the swirled/spun read:
//   * keeps the real convex MAGNIFICATION (the droplet still enlarges what is
//     under it and the underlying image stays RECOGNISABLE inside the lens),
//     the bright glass RIM, the specular kick and the decisive inner-glow.
//   * GREATLY softens the mid-lens ring displacement that produces the spun
//     vortex look: LENS_AMP is dropped (1.6 → 0.7) and the inward displacement
//     factor is reduced (0.26 → 0.12), so straight features gently BOW rather
//     than smear into a swirl.
//   * reduces chromatic split to a subtle hint (CHROMA_PX 16 → 6) — premium,
//     not a rainbow fringe.
// Outside the lens the image is untouched. uActive fades the whole effect.
//
// All headline magnitudes are named constants below so the warp stays tunable.

precision highp float;

uniform vec2 uSize;    // canvas size in px           (indices 0,1)
uniform vec2 uOrb;     // lens center in px           (indices 2,3)
uniform float uRadius; // lens radius in px           (index 4)
uniform float uMag;    // magnification 0..1          (index 5)
uniform float uActive; // overall strength 0..1       (index 6)
uniform sampler2D uTex;

out vec4 fragColor;

// ---- Tunable look constants (CALM) -----------------------------------------
const float LENS_AMP   = 0.7;   // radial displacement amplitude (was 1.6 "vif")
const float MAG_AMP    = 1.0;   // extra magnification toward the centre (kept)
const float DISP_FAC   = 0.12;  // mid-lens inward displacement (was 0.26 "vif")
const float CHROMA_PX  = 6.0;   // chromatic split at the rim, in px (was 16)
const float RIM_BRIGHT = 0.70;  // brightness of the glass rim highlight (kept)
const float SPEC_BRIGHT = 0.50; // upper-left specular kick brightness (kept)
const float INNER_GLOW = 0.045; // gentle inner luminosity (droplet, not ring)

void main() {
  vec2 pos = FlutterFragCoord().xy;
  vec2 uv = pos / uSize;
  vec3 base = texture(uTex, uv).rgb;

  float r = uRadius;
  vec2 d = pos - uOrb;
  float dist = length(d);

  if (uActive < 0.001 || dist >= r) {
    fragColor = vec4(base, 1.0);
    return;
  }

  float nd = dist / r;                          // 0 center .. 1 rim
  float bulge = 1.0 - nd * nd;                  // convex droplet falloff (1..0)
  float dome = sqrt(max(0.0, bulge));           // spherical profile
  vec2 dir = dist > 0.0001 ? d / dist : vec2(0.0);

  // --- Convex lens: collapse the sample radius toward the centre. ---------
  // Magnification (k) is UNCHANGED from the vif lens so the content stays
  // enlarged and recognisable; only the mid-lens displacement is softened so
  // straight features gently bow instead of smearing into a vortex.
  float mag = (uMag * MAG_AMP);
  float k = 1.0 - mag * bulge;                  // central zoom (kept)
  float lens = LENS_AMP * mag * sin(nd * 3.14159265); // peaks mid-lens (softened)
  vec2 sPos = uOrb + d * k - dir * (lens * r * DISP_FAC);
  vec2 sUv = sPos / uSize;

  // --- Chromatic aberration: subtle hint toward the rim. -----------------
  float ca = (CHROMA_PX * nd * nd) / max(uSize.x, uSize.y);
  float rC = texture(uTex, sUv + dir * ca).r;
  float gC = texture(uTex, sUv).g;
  float bC = texture(uTex, sUv - dir * ca).b;
  vec3 col = vec3(rC, gC, bC);

  // --- Curvature darkening just inside the rim (reads as a dome). ---------
  float curve = smoothstep(0.55, 1.0, nd);
  col *= mix(1.0, 0.86, curve);

  // --- Gentle inner luminosity so the bead GLOWS (droplet, not a ring). ---
  col += vec3(0.92, 0.97, 0.94) * INNER_GLOW * dome;

  // --- Sea-glass rim tint (subtle aura, not a flat fill). ----------------
  float rimTint = smoothstep(0.72, 1.0, nd);
  vec3 seaGlass = vec3(0.37, 0.72, 0.66);
  col = mix(col, col * 0.82 + seaGlass * 0.30, rimTint * 0.45);

  // --- Bright soft GLASS RIM ring at the bead edge. ----------------------
  float ring = smoothstep(0.84, 0.95, nd) * (1.0 - smoothstep(0.95, 1.0, nd));
  col += vec3(0.96, 0.99, 0.97) * ring * RIM_BRIGHT;

  // --- Upper-left specular kick — the wet-glass shine. -------------------
  vec2 hl = uOrb + vec2(-r * 0.34, -r * 0.36);
  float hd = length(pos - hl) / (r * 0.6);
  col += vec3(1.0) * (1.0 - smoothstep(0.0, 1.0, hd)) * SPEC_BRIGHT * dome;

  // --- Soft edge: melt the lens back into the untouched image. -----------
  float edge = smoothstep(1.0, 0.90, nd);
  col = mix(base, col, edge * uActive);

  fragColor = vec4(col, 1.0);
}
