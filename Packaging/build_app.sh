#!/bin/bash
# Builds PhotoCleaner with SwiftPM and assembles a proper .app bundle so macOS grants
# it a real Info.plist (required for the Photos permission prompt to work) and a
# code signature (required for TCC to key a permission entry to this app at all).
#
# This targets local/direct-distribution use per PRD section 7 ("may need to evaluate
# direct distribution (notarized, outside App Store) as an alternative"). It is
# ad-hoc signed for local development; a notarized release build would instead sign
# with a Developer ID certificate and staple a notarization ticket.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"

echo "==> Building PhotoCleaner ($CONFIGURATION)…"
cd "$ROOT_DIR"
if [ "$CONFIGURATION" = "release" ]; then
    swift build -c release
    BIN_DIR="$ROOT_DIR/.build/release"
else
    swift build
    BIN_DIR="$ROOT_DIR/.build/debug"
fi

APP_NAME="PhotoCleaner.app"
APP_DIR="$ROOT_DIR/.build/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Assembling app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/PhotoCleaner" "$MACOS_DIR/PhotoCleaner"
cp "$ROOT_DIR/Packaging/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "==> Ad-hoc code signing…"
codesign --force --deep --sign - \
    --entitlements "$ROOT_DIR/Packaging/PhotoCleaner.entitlements" \
    "$APP_DIR"

echo "==> Verifying signature…"
codesign --verify --verbose "$APP_DIR"

echo "==> Done: $APP_DIR"
