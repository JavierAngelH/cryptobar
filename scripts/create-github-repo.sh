#!/usr/bin/env bash
set -euo pipefail

# Creates the GitHub repo and pushes this project.
# Requires: gh auth login (run once on your Mac)

REPO="${1:-cryptobar}"
VISIBILITY="${2:-public}"

if ! gh auth status >/dev/null 2>&1; then
  echo "Run 'gh auth login' first, then re-run this script."
  exit 1
fi

gh repo create "$REPO" --public --source=. --remote=github --push --description "macOS menu bar crypto price ticker powered by CoinGecko"
echo "Done: https://github.com/$(gh api user -q .login)/$REPO"
