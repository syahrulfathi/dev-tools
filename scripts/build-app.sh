#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
swift build -c release -debug-info-format none --product dev-tools --disable-sandbox --cache-path "$PWD/.build/cache"
BUILD_DIR="$(swift build -c release -debug-info-format none --disable-sandbox --cache-path "$PWD/.build/cache" --show-bin-path)"
APP="$PWD/dist/dev-tools.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD_DIR/dev-tools" "$APP/Contents/MacOS/dev-tools"
# SwiftPM locates the resource bundle next to the executable inside the app.
find "$BUILD_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/MacOS/" \;
find "$BUILD_DIR" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>dev-tools</string>
<key>CFBundleDisplayName</key><string>dev-tools</string>
<key>CFBundleIdentifier</key><string>local.dev-tools.app</string>
<key>CFBundleVersion</key><string>2</string>
<key>CFBundleShortVersionString</key><string>1.1.0</string>
<key>CFBundleExecutable</key><string>dev-tools</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
swift scripts/make-icon.swift "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep --sign - "$APP"
echo "Built: $APP"
