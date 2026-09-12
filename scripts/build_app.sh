#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

echo "==> Building Face ID for Mac (Release configuration)..."
swift build -c release

APP_NAME="FaceIDMac"
BUILD_DIR="$ROOT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Constructing $APP_NAME.app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
cp "$ROOT_DIR/.build/release/FaceIDMac" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

# Copy Info.plist
cp "$ROOT_DIR/Support/Info.plist" "$CONTENTS_DIR/Info.plist"

# Copy Resources
cp "$ROOT_DIR/Sources/FaceIDMac/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
cp "$ROOT_DIR/Sources/FaceIDMac/Resources/player.html" "$RESOURCES_DIR/player.html"
cp "$ROOT_DIR/Sources/FaceIDMac/Resources/AppleFaceID.json" "$RESOURCES_DIR/AppleFaceID.json"
cp "$ROOT_DIR/Sources/FaceIDMac/Resources/lottie.min.js" "$RESOURCES_DIR/lottie.min.js"
cp "$ROOT_DIR/Sources/FaceIDMac/Resources/Apple Face ID.gif" "$RESOURCES_DIR/Apple Face ID.gif" 2>/dev/null || true

# Copy SPM Resource Bundle if generated
if [ -d "$ROOT_DIR/.build/release/FaceIDMac_FaceIDMac.bundle" ]; then
    cp -R "$ROOT_DIR/.build/release/FaceIDMac_FaceIDMac.bundle" "$RESOURCES_DIR/"
fi

# Code sign with entitlements
echo "==> Signing application bundle..."
codesign --force --deep --sign - --entitlements "$ROOT_DIR/FaceIDMac.entitlements" "$APP_BUNDLE"

# Mirror to project root for convenience
rm -rf "$ROOT_DIR/FaceIDMac.app"
cp -R "$APP_BUNDLE" "$ROOT_DIR/FaceIDMac.app"

echo "==> Build complete! Application available at: $ROOT_DIR/FaceIDMac.app"
