#!/usr/bin/env bash
# ============================================================================
# Vybia V2 — one-command deploy (S13: CLOUD BUILD).
#
# This Mac's GPU kernel-panics on heavy load, so it NEVER compiles Vybia.
# Instead, a `git push` makes a GitHub-hosted runner build Flutter web and
# publish it to GitHub Pages (see .github/workflows/deploy.yml).
#
# This script is therefore TRIVIAL on purpose: it only commits and pushes.
# The heavy compile happens in the cloud.
#
#   Usage:  ./tool/deploy.sh ["optional commit message"]
#
# After it pushes, watch the build and get the live URL with:
#   gh run watch        # follow the latest Actions run
#   gh run list         # see recent runs
#
# (The old local-build + Cloudflare-tunnel flow is kept as a fallback in
#  tool/deploy_local_tunnel.sh — do NOT use it on this Mac; it compiles locally.)
# ============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

MSG="${1:-deploy}"

git add -A
if git diff --cached --quiet; then
  echo "==> Nothing to commit — pushing current main to trigger a rebuild anyway."
else
  git commit -m "$MSG"
fi

echo "==> Pushing to origin/main (this triggers the cloud build + deploy)…"
git push origin main

echo
echo "============================================================"
echo "  Pushed. The cloud is now building Vybia web."
echo
echo "  Watch it:        gh run watch"
echo "  Live URL (Pages): printed at the end of the run, e.g."
REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
if [ -n "$REPO_SLUG" ]; then
  OWNER="${REPO_SLUG%%/*}"
  NAME="${REPO_SLUG##*/}"
  echo "                   https://${OWNER}.github.io/${NAME}/"
fi
echo
echo "  Open that URL on your iPHONE — NOT in Chrome on this Mac."
echo "============================================================"
