#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$ROOT_DIR"

# Ensure app is built
if [ ! -d "$ROOT_DIR/FaceIDMac.app" ]; then
    echo "==> FaceIDMac.app not found. Building now..."
    "$SCRIPT_DIR/build_app.sh"
fi

DMG_NAME="Face ID for Mac"
DMG_PATH="$ROOT_DIR/$DMG_NAME.dmg"
STAGING_DIR="$ROOT_DIR/build/dmg_staging"

echo "==> Creating DMG staging environment..."
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy Application bundle
cp -R "$ROOT_DIR/FaceIDMac.app" "$STAGING_DIR/"

# Create /Applications symlink for drag-and-drop install
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating $DMG_NAME.dmg via hdiutil..."
hdiutil create -volname "$DMG_NAME" \
               -srcfolder "$STAGING_DIR" \
               -ov \
               -format UDZO \
               "$DMG_PATH"

rm -rf "$STAGING_DIR"

echo "==> DMG successfully created at: $DMG_PATH"
