#!/bin/bash
set -euo pipefail

# Build Copilot Island.app and package it into a fancy DMG
# Usage: ./scripts/build-dmg.sh [--skip-build]

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEME="copilot-island"
APP_BUNDLE_NAME="Copilot Island"
APP_SLUG="copilot-island"
BUILD_DIR="$REPO_ROOT/build"
DMG_DIR="$BUILD_DIR/dmg"
APP_PATH="$BUILD_DIR/Release/${APP_BUNDLE_NAME}.app"
VOLUME_NAME="Copilot Island"
# Window and icon layout
WIN_W=600
WIN_H=400
ICON_SIZE=96
APP_X=120
APP_Y=100
LINK_X=380
LINK_Y=100

SKIP_BUILD=false
if [[ "${1:-}" == "--skip-build" ]]; then
    SKIP_BUILD=true
fi

# Read version from plugin.json (single source of truth)
VERSION=$(python3 -c "import json; print(json.load(open('$REPO_ROOT/plugin/plugin.json'))['version'])")
DMG_NAME="${APP_SLUG}-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/${DMG_NAME}"
DMG_RW="$BUILD_DIR/dmg-rw.dmg"

echo "==> Building ${APP_BUNDLE_NAME} v${VERSION}"

# Build release archive
if [ "$SKIP_BUILD" = false ]; then
    echo "==> Compiling Release build..."
    xcodebuild -project "$REPO_ROOT/copilot-island.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        -destination 'platform=macOS' \
        CONFIGURATION_BUILD_DIR="$BUILD_DIR/Release" \
        clean build 2>&1 | tail -5

    if [ ! -d "$APP_PATH" ]; then
        echo "ERROR: Build failed — $APP_PATH not found"
        exit 1
    fi
fi

echo "==> App built at: $APP_PATH"

# Prepare DMG layout with background
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR/.background"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

# Generate/copy DMG background (prefer checked-in asset, then script, then inline fallback)
BKG_SRC="$REPO_ROOT/scripts/dmg-background.png"
BKG_OUT="$DMG_DIR/.background/background.png"
if [ -f "$BKG_SRC" ]; then
    cp "$BKG_SRC" "$BKG_OUT"
    echo "==> Using background image: $BKG_SRC"
elif [ -f "$REPO_ROOT/scripts/make-dmg-background.py" ]; then
    python3 "$REPO_ROOT/scripts/make-dmg-background.py" "$BKG_OUT"
else
    echo "==> No background asset found; generating fallback gradient..."
    python3 - "$BKG_OUT" <<'PY'
import struct
import sys
import zlib

out = sys.argv[1]
w, h = 600, 400
sig = b"\x89PNG\r\n\x1a\n"

def chunk(kind, data):
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    )

ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
rows = bytearray()
for y in range(h):
    t = y / (h - 1)
    r = int(0x1A + (0x2D - 0x1A) * t)
    g = int(0x36 + (0x5A - 0x36) * t)
    b = int(0x5D + (0x7A - 0x5D) * t)
    rows.append(0)
    rows.extend(bytes([r, g, b]) * w)

png = sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
with open(out, "wb") as f:
    f.write(png)
print(f"Wrote {out}")
PY
fi

# Create a read-write DMG, mount it, copy content, then customize with AppleScript
echo "==> Creating DMG (read-write)..."
rm -f "$DMG_RW"
hdiutil create -size 50m -volname "$VOLUME_NAME" -fs HFS+ -layout SPUD \
    -nospotlight "$DMG_RW" -ov

MOUNT_POINT="/Volumes/$VOLUME_NAME"
# Unmount if left over from a previous run
hdiutil detach "$MOUNT_POINT" 2>/dev/null || true

hdiutil attach "$DMG_RW" -nobrowse -noverify -noautoopen -readwrite

# Copy layout (app, Applications symlink, .background) into the volume
cp -R "$APP_PATH" "$MOUNT_POINT/"
ln -s /Applications "$MOUNT_POINT/Applications"
mkdir -p "$MOUNT_POINT/.background"
cp "$DMG_DIR/.background/background.png" "$MOUNT_POINT/.background/"

# Set Finder view: icon view, background, icon size, icon positions, window size
echo "==> Applying DMG layout..."
APP_ITEM="${APP_BUNDLE_NAME}.app"
VOL_PATH="/Volumes/$VOLUME_NAME"
BKG_PATH="$VOL_PATH/.background/background.png"
WIN_R=$((200+WIN_W))
WIN_B=$((120+WIN_H))

APPLESCRIPT_FILE=$(mktemp)
trap 'rm -f "$APPLESCRIPT_FILE"' EXIT
cat <<EOF > "$APPLESCRIPT_FILE"
tell application "Finder"
    set volPath to POSIX file "$VOL_PATH" as alias
    set appName to "$APP_ITEM"
    open volPath
    set w to front window
    set current view of w to icon view
    set v to icon view options of w
    set arrangement of v to not arranged
    set icon size of v to $ICON_SIZE
    set background picture of v to (POSIX file "$BKG_PATH" as alias)
    set shows icon preview of v to false
    set shows item info of v to false
    set toolbar visible of w to false
    set statusbar visible of w to false
    set bounds of w to {200, 120, $WIN_R, $WIN_B}
    set position of file appName of target of w to {$APP_X, $APP_Y}
    set position of item "Applications" of target of w to {$LINK_X, $LINK_Y}
    close w
end tell
EOF
osascript "$APPLESCRIPT_FILE"

# Optional: set volume icon to app icon (makes mounted DMG look branded)
ICON_RSRC="$MOUNT_POINT/.VolumeIcon.icns"
if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    cp "$APP_PATH/Contents/Resources/AppIcon.icns" "$ICON_RSRC"
    SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
fi

hdiutil detach "$MOUNT_POINT" -quiet

# Convert to compressed read-only
rm -f "$DMG_PATH"
echo "==> Compressing DMG..."
hdiutil convert "$DMG_RW" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$DMG_RW"
rm -rf "$DMG_DIR"

echo ""
echo "==> Done! DMG created at:"
echo "    $DMG_PATH"
echo "    Size: $(du -h "$DMG_PATH" | cut -f1)"
