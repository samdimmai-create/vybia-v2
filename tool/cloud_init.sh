#!/usr/bin/env bash
# ============================================================================
# Vybia V2 — S13 ONE-TIME cloud setup (run once, after `gh auth login`).
#
# Creates the private GitHub repo, enables GitHub Pages (source = Actions),
# pushes main → the cloud builds + publishes → prints the live URL.
#
# Nothing compiles on this Mac. Run once; after this, deploys are just
# `./tool/deploy.sh`.
#
#   Usage:  ./tool/cloud_init.sh
# ============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

REPO_NAME="vybia-v2"

echo "==> Checking GitHub auth…"
if ! gh auth status >/dev/null 2>&1; then
  echo "!! Not logged in. Run:  gh auth login   (then re-run this script)." >&2
  exit 1
fi

USER_LOGIN="$(gh api user -q .login)"
echo "    Authenticated as: $USER_LOGIN"

# 1) Create the repo (private) if it doesn't already exist, with this dir as source.
if gh repo view "$USER_LOGIN/$REPO_NAME" >/dev/null 2>&1; then
  echo "==> Repo $USER_LOGIN/$REPO_NAME already exists — ensuring 'origin' remote."
  git remote get-url origin >/dev/null 2>&1 || \
    git remote add origin "https://github.com/$USER_LOGIN/$REPO_NAME.git"
else
  echo "==> Creating private repo $USER_LOGIN/$REPO_NAME…"
  gh repo create "$REPO_NAME" --private --source=. --remote=origin
fi

# 2) Enable GitHub Pages with the GitHub Actions build type (idempotent).
echo "==> Enabling GitHub Pages (source = GitHub Actions)…"
gh api -X POST "repos/$USER_LOGIN/$REPO_NAME/pages" -f build_type=workflow >/dev/null 2>&1 \
  || gh api -X PUT "repos/$USER_LOGIN/$REPO_NAME/pages" -f build_type=workflow >/dev/null 2>&1 \
  || echo "    (Pages may already be enabled — continuing.)"

# 3) Push main → triggers .github/workflows/deploy.yml (cloud build + deploy).
echo "==> Pushing main (triggers the cloud build)…"
git push -u origin main

echo
echo "============================================================"
echo "  Setup done. The cloud is building Vybia web now."
echo
echo "  Follow the build:   gh run watch"
echo "  List runs:          gh run list"
echo
echo "  When the run is green, open this on your iPHONE:"
echo
echo "      https://${USER_LOGIN}.github.io/${REPO_NAME}/"
echo
echo "  Do NOT open it in Chrome on this Mac (GPU panic)."
echo "  Future updates: just run  ./tool/deploy.sh"
echo "============================================================"
