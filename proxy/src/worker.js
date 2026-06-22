// ============================================================================
// Vybia V2 — Claude proxy (Cloudflare Worker) — S15A
//
// PURPOSE: hold the Anthropic API key as a SERVER-SIDE secret and forward a
// small, structured language-generation request to the Anthropic Messages API.
// The public Vybia web app calls THIS worker's URL (public is fine — it does not
// expose the key); the key lives only as a Cloudflare secret (`ANTHROPIC_API_KEY`).
//
// SECURITY CONTRACT:
//   * The key is read ONLY from `env.ANTHROPIC_API_KEY` (a Cloudflare secret).
//   * The key is NEVER returned to the client and NEVER logged.
//   * CORS is restricted to the Vybia GitHub Pages origin (+ localhost for dev).
//
// COST GUARDRAILS (the engine already did the reasoning — Claude only writes a
// short phrase): a low `max_tokens` cap, the model `claude-haiku-4-5` (fast +
// cheap), and a best-effort per-IP rate limit. The founder should ALSO set a
// spend limit in the Anthropic console (the proxy can't enforce billing).
//
// REQUEST  (POST, JSON body):  { system, context, task, maxTokens? }
// RESPONSE (JSON):             { text }      // generated text only
// ============================================================================

// The model the proxy calls. Fast + cheap — right for short copy generation.
const MODEL = "claude-haiku-4-5";
const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";

// Hard ceiling on generated tokens, regardless of what the client asks for.
// Vybia only needs a sentence or two, so keep this small to bound cost.
const MAX_TOKENS_CAP = 320;

// Allowed browser origins. The Vybia app is served from GitHub Pages; localhost
// is permitted so the proxy can be exercised during development.
const ALLOWED_ORIGINS = new Set([
  "https://samdimmai-create.github.io",
  "http://localhost:8080",
  "http://127.0.0.1:8080",
]);

// Best-effort per-IP rate limit. NOTE: Workers are stateless across isolates, so
// this bucket is per-isolate and resets on cold starts — it's a cheap abuse
// brake, not a hard quota. The real cost ceiling is MAX_TOKENS_CAP + the spend
// limit the founder sets in the Anthropic console.
const RATE_WINDOW_MS = 60_000;
const RATE_MAX_HITS = 30; // per IP per window
const hits = new Map(); // ip -> { count, resetAt }

function rateLimited(ip) {
  const now = Date.now();
  const entry = hits.get(ip);
  if (!entry || now > entry.resetAt) {
    hits.set(ip, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return false;
  }
  entry.count += 1;
  return entry.count > RATE_MAX_HITS;
}

function corsHeaders(origin) {
  const allow = ALLOWED_ORIGINS.has(origin) ? origin : "null";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

function json(body, status, origin) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders(origin) },
  });
}

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";

    // CORS preflight.
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    if (request.method !== "POST") {
      return json({ error: "method_not_allowed" }, 405, origin);
    }
    if (!env.ANTHROPIC_API_KEY) {
      // Misconfigured deploy — the app silently falls back to its templates.
      return json({ error: "proxy_not_configured" }, 503, origin);
    }

    const ip = request.headers.get("CF-Connecting-IP") || "unknown";
    if (rateLimited(ip)) {
      return json({ error: "rate_limited" }, 429, origin);
    }

    let payload;
    try {
      payload = await request.json();
    } catch (_) {
      return json({ error: "bad_request" }, 400, origin);
    }

    const system = typeof payload.system === "string" ? payload.system : "";
    const task = typeof payload.task === "string" ? payload.task : "";
    const context = payload.context ?? null;
    const maxTokens = Math.min(
      Number.isFinite(payload.maxTokens) ? payload.maxTokens : 120,
      MAX_TOKENS_CAP,
    );
    if (!task) {
      return json({ error: "bad_request" }, 400, origin);
    }

    // The engine's real context travels as compact JSON so Claude stays grounded
    // in the chosen activity / factors and never invents places.
    const userContent =
      context == null ? task : `${task}\n\nCONTEXT (JSON):\n${JSON.stringify(context)}`;

    let upstream;
    try {
      upstream = await fetch(ANTHROPIC_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": env.ANTHROPIC_API_KEY,
          "anthropic-version": ANTHROPIC_VERSION,
        },
        body: JSON.stringify({
          model: MODEL,
          max_tokens: maxTokens,
          system,
          messages: [{ role: "user", content: userContent }],
        }),
      });
    } catch (_) {
      // Never echo the error detail — it could carry request internals.
      return json({ error: "upstream_unreachable" }, 502, origin);
    }

    if (!upstream.ok) {
      // Surface only the status; never the key or upstream body.
      return json({ error: "upstream_error", status: upstream.status }, 502, origin);
    }

    let data;
    try {
      data = await upstream.json();
    } catch (_) {
      return json({ error: "upstream_bad_json" }, 502, origin);
    }

    const text = Array.isArray(data.content)
      ? data.content
          .filter((b) => b && b.type === "text" && typeof b.text === "string")
          .map((b) => b.text)
          .join("")
          .trim()
      : "";

    return json({ text }, 200, origin);
  },
};
