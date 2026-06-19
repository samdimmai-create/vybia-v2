#version 460 core
#include <flutter/runtime_effect.glsl>

// Vybia universal "liquid-glass bubble" refraction.
//
// Samples the rendered background image (uTex) and, inside a circular lens of
// radius uRadius centered on uOrb, applies:
//   * spherical refraction (samples bent inward, strongest mid-lens),
//   * chromatic fringe that grows toward the rim,
//   * a specular highlight near the upper-left,
//   * a sea-glass rim tint + curvature darkening,
//   * a soft edge so the lens melts into the image.
// Outside the lens the image is untouched. uActive fades the whole effect.

precision highp float;

uniform vec2 uSize;    // canvas size in px           (indices 0,1)
uniform vec2 uOrb;     // lens center in px           (indices 2,3)
uniform float uRadius; // lens radius in px           (index 4)
uniform float uMag;    // magnification 0..1          (index 5)
uniform float uActive; // overall strength 0..1       (index 6)
uniform sampler2D uTex;

out vec4 fragColor;

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
  float dome = sqrt(max(0.0, 1.0 - nd * nd));   // spherical profile

  // Refraction: bend the sample inward, strongest in the dome's middle.
  float pull = mix(1.0, 1.0 - uMag, dome);
  vec2 sPos = uOrb + d * pull;
  vec2 sUv = sPos / uSize;

  // Chromatic fringe grows toward the rim.
  vec2 dir = dist > 0.0001 ? d / dist : vec2(0.0);
  float fringe = smoothstep(0.55, 1.0, nd) * (6.0 / max(uSize.x, uSize.y));
  float rC = texture(uTex, sUv + dir * fringe).r;
  float gC = texture(uTex, sUv).g;
  float bC = texture(uTex, sUv - dir * fringe).b;
  vec3 col = vec3(rC, gC, bC);

  // Specular highlight near the upper-left of the lens.
  vec2 hl = uOrb + vec2(-r * 0.32, -r * 0.34);
  float hd = length(pos - hl) / (r * 0.9);
  col += vec3(0.90, 0.95, 0.92) * (1.0 - smoothstep(0.0, 1.0, hd)) * 0.30 * dome;

  // Sea-glass rim tint + curvature darkening.
  float rim = smoothstep(0.80, 1.0, nd);
  vec3 seaGlass = vec3(0.37, 0.72, 0.66);
  col = mix(col, col * 0.78 + seaGlass * 0.35, rim * 0.6);

  // Soft edge: blend the lens back into the untouched image at the boundary.
  float edge = smoothstep(1.0, 0.90, nd);
  col = mix(base, col, edge * uActive);

  fragColor = vec4(col, 1.0);
}
