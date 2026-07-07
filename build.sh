#!/bin/bash
set -e

APP_NAME="MouseJiggler"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "Quitting any running instance of $APP_NAME..."
killall "$APP_NAME" 2>/dev/null && echo "  (was running — stopped it)" || echo "  (none was running)"

echo "Cleaning previous build..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "No icon found — generating one from Resources/AppIcon-1024.png..."
    ./scripts/make_icon.sh
fi

echo "Compiling Swift sources..."
swiftc -O Sources/*.swift -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

echo "Copying resources..."
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✅ Done! App bundle created at: $APP_BUNDLE"
echo ""
echo "Next steps:"
echo "  1. rm -rf \"/Applications/$APP_NAME.app\""
echo "  2. mv \"$APP_BUNDLE\" /Applications/"
echo "  3. open /Applications/$APP_NAME.app"
echo "  4. Grant Accessibility permission if/when asked"
echo "     (System Settings > Privacy & Security > Accessibility)"
