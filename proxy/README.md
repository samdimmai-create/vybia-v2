# Vybia Claude proxy (Cloudflare Worker)

A tiny serverless proxy that holds the **Anthropic API key as a server-side
secret** and forwards short language-generation requests to the Anthropic
Messages API (`claude-haiku-4-5`). The public Vybia web app calls this worker's
URL — the key is never in the web bundle, never in git, never echoed.

## Why a proxy

The Vybia web app is a **public** static bundle (GitHub Pages). Anything baked
into it is readable by anyone. The Anthropic key must therefore live somewhere
the public can't read — here, as a Cloudflare **secret**. The app only knows the
proxy's public URL, which is safe to expose.

## THE ONE FOUNDER STEP (do this once)

You need a free [Cloudflare](https://dash.cloudflare.com/sign-up) account.

```bash
cd proxy
npm install -g wrangler        # or: npx wrangler ...
wrangler login                 # opens a browser, one click
wrangler secret put ANTHROPIC_API_KEY
#   ^ paste your Anthropic key when prompted. It goes straight to Cloudflare
#     as a secret — NOT into git, NOT into any file here.
wrangler deploy                # prints the public URL, e.g.
#   https://vybia-claude-proxy.<your-subdomain>.workers.dev
```

Copy that **public URL** — it is what the app uses as `PROXY_URL` (see the repo
variable step in the main S15 report). It is *not* a secret; it does not expose
the key.

> Also recommended: set a **spend limit** in the Anthropic console
> (Settings → Limits) so a runaway never costs more than you intend.

## Rotating the key

Run `wrangler secret put ANTHROPIC_API_KEY` again with the new key, then
`wrangler deploy`. The old key stops being used immediately. Revoke the old key
in the Anthropic console.

## Cost guardrails (built in)

- Model `claude-haiku-4-5` — fast and cheap; the deterministic engine already
  did the reasoning, Claude only writes a short phrase.
- `max_tokens` capped at 320 in the worker (`MAX_TOKENS_CAP`).
- Best-effort per-IP rate limit (30 req / 60 s per isolate).
- CORS restricted to the Vybia GitHub Pages origin.

## Local dev

```bash
cd proxy
echo 'ANTHROPIC_API_KEY = "sk-ant-..."' > .dev.vars   # gitignored; never commit
wrangler dev
```

`.dev.vars` and `node_modules/` are gitignored.
