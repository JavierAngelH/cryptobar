#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/CryptoBar.app"
DEST="/Applications/CryptoBar.app"

if [[ ! -d "$APP" ]]; then
  echo "CryptoBar.app not found. Build first:"
  echo "  ./scripts/build-release.sh"
  exit 1
fi

echo "Installing to $DEST ..."
sudo rm -rf "$DEST"
sudo cp -R "$APP" "$DEST"
sudo xattr -cr "$DEST" 2>/dev/null || true

echo ""
echo "Installed! Open from Applications or run:"
echo "  open /Applications/CryptoBar.app"
echo ""
echo "Tip: enable Launch at Login in CryptoBar Settings so it starts after reboot."
