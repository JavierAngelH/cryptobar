#!/usr/bin/env bash
set -euo pipefail

# Builds a Release .app you can run without Xcode open.
# Requires: Xcode (command-line tools alone are not enough for SwiftUI apps).

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null; then
  echo "Install XcodeGen first: brew install xcodegen"
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Install Xcode from the App Store, then run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

echo "Generating Xcode project..."
xcodegen generate

echo "Building Release..."
xcodebuild \
  -project CryptoBar.xcodeproj \
  -scheme CryptoBar \
  -configuration Release \
  -derivedDataPath "$ROOT/build/DerivedData" \
  build

APP="$ROOT/build/DerivedData/Build/Products/Release/CryptoBar.app"

if [[ ! -d "$APP" ]]; then
  echo "Build failed — CryptoBar.app not found."
  exit 1
fi

mkdir -p "$ROOT/build"
rm -rf "$ROOT/build/CryptoBar.app"
cp -R "$APP" "$ROOT/build/CryptoBar.app"

echo ""
echo "Done! Your app is ready:"
echo "  $ROOT/build/CryptoBar.app"
echo ""
echo "Install to Applications:"
echo "  ./scripts/install-local.sh"
echo ""
echo "Or double-click build/CryptoBar.app to run it."
