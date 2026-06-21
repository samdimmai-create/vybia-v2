# S13 — Cloud build + deploy (compile OFF this Mac)

**Goal:** a `git push` → a GitHub-hosted runner builds Flutter web → a public
GitHub Pages URL is published/updated. **Nothing compiles or renders on the
founder's Mac, ever.** Future updates = `./tool/deploy.sh`.

## Why cloud
This fanless MacBook Air kernel-panics under sustained GPU/compile load (iOS
sim, `flutter run`, Chrome rendering the app, and even `flutter build web`
rebooted it at ~56s). So the heavy compile was moved entirely to a free
GitHub Actions runner. Local ops are limited to editing, `git`, `gh`, CI config.

## What the agent set up (no local compile)
1. **`gh` CLI installed** via Homebrew (`gh 2.95.0`) — light op.
2. **`.github/workflows/deploy.yml`** — on push to `main` (or manual dispatch):
   - `actions/checkout@v4`
   - `subosito/flutter-action@v2`, Flutter **3.44.1 / stable**, cache on
   - `flutter pub get`
   - `flutter build web --release --base-href "/<repo>/"` — **KEYLESS** (no
     TMDB / Ticketmaster secrets baked into the public bundle, by design)
   - `actions/upload-pages-artifact@v3` → `actions/deploy-pages@v4`
   - permissions `pages: write`, `id-token: write`; `concurrency: pages`,
     `cancel-in-progress: false`
3. **`tool/deploy.sh`** rewritten — trivial on purpose: `git add -A` +
   commit + `git push origin main` (triggers the cloud rebuild) and prints the
   Pages URL + `gh run watch` hint.
4. **`tool/deploy_local_tunnel.sh`** — the previous S12 local-build + Cloudflare
   tunnel script, **preserved as a fallback** (it compiles locally, so do NOT
   use it on this Mac).
5. **`tool/cloud_init.sh`** — one-time setup to run right after auth: creates
   the private repo, enables Pages (source = GitHub Actions), pushes `main`.
   Idempotent.
6. Verified **no secrets staged** — `tool/secrets.env` stays gitignored; the
   web `index.html` already uses the `$FLUTTER_BASE_HREF` placeholder, so the
   `--base-href /<repo>/` is applied at build time.

Two local commits made on `main` (workflow + 3 scripts + report).

## The ONE founder step (GitHub auth)
`gh` was not authenticated and this is the only thing the agent cannot do:

```
cd ~/Desktop/vybia-v2
gh auth login        # choose GitHub.com → HTTPS → "Login with a web browser"
                     # it shows a one-time code + opens github.com/login/device
                     # paste the code there to authorize
```

(If the founder has no GitHub account: create one at github.com — ~2 min — then
run `gh auth login`.)

Then, **one command** finishes everything:

```
./tool/cloud_init.sh
```

This creates `vybia-v2` (private), enables Pages, pushes `main`, and the cloud
build starts automatically.

## Agent did vs founder does
| Step | Who |
|---|---|
| Install `gh`, write workflow + scripts, commit locally, secret check | **Agent** (done) |
| `gh auth login` (device-code) | **Founder** (one step) |
| `./tool/cloud_init.sh` (repo create + Pages + push) | Founder runs; script automates |
| Watch build / open URL on iPhone | Founder |

## Live URL (after first green run)
```
https://<your-github-username>.github.io/vybia-v2/
```
**Open it on your iPHONE or another computer — NOT in Chrome on this Mac.**
Follow the build with `gh run watch`; the exact URL also prints at the end of
the Actions run and at the bottom of `cloud_init.sh` / `deploy.sh`.

## What's live vs standby on that URL
- **Live (keyless):** weather-filtered recommendations (Open-Meteo), real
  Montréal open-data events, Geoapify-enriched place hours (baked at ingest),
  offline-safe fallback.
- **Standby (by design):** TMDB films + Ticketmaster events — no keys baked
  into the public bundle. They light up only when keys are provided via
  `--dart-define` in a private build.

## How to redeploy later
```
./tool/deploy.sh ["optional message"]   # commit + push → cloud rebuilds + republishes
gh run watch                            # follow it
```

## Outcome — LIVE ✅
**Live URL:** https://samdimmai-create.github.io/vybia-v2/  (HTTP 200, serves the
Flutter web app). Open it on your iPhone — NOT in Chrome on this Mac.

What actually happened during setup (recorded for the next time):
1. `gh` installed via Homebrew; founder did `gh auth login` (one step).
2. `tool/cloud_init.sh` created the repo and pushed.
3. **Big-history push:** `.git` is ~385 MB (screenshots tracked since S0). A
   single push timed out (HTTP 408), so main was pushed in **incremental commit
   batches** (each batch only uploads new objects → each stays under the
   timeout). All 70 commits landed.
4. **`workflow` scope:** the default `gh` token lacked the `workflow` scope, so
   the final commit (which adds `.github/workflows/deploy.yml`) was rejected.
   Founder ran `gh auth refresh -s workflow` (device code) → final push went in.
5. **Private repo + free plan = no Pages.** GitHub Pages needs a paid plan for
   private repos. Founder chose to make the repo **public** (the build is
   keyless and no secret is committed, so public is safe). `gh repo edit
   --visibility public` + enable Pages (`build_type=workflow`).
6. First Actions run: **build job succeeded** (Flutter web compiled in the
   cloud, ~2m50s); deploy step had 404'd only because Pages wasn't enabled yet.
   Re-ran the failed deploy job → **success**, site live.

## Status: DONE
- Repo `samdimmai-create/vybia-v2` (**public**), `main` pushed (70 commits).
- `.github/workflows/deploy.yml` live; first cloud build green; Pages serving.
- `tool/deploy.sh` = one-command future deploys. No secret in git.
- No local `flutter build`/run/simulator/Chrome was used at any point.
