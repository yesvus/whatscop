#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP="$ROOT/build/WhatsCop.app"
RESOURCES="$APP/Contents/Resources"
ICONSET="$ROOT/build/AppIcon.iconset"
mkdir -p "$ROOT/build"
rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$RESOURCES" "$ICONSET"
cp "$ROOT/WhatsCop/Info.plist" "$APP/Contents/Info.plist"

# Process the user-selected logo locally; icon corners are transparent.
swift "$ROOT/generate_icon.swift" "$ROOT/Resources/IconSource.png" "$ROOT/build/IconTransparent.png"
for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" "512 512x512" "1024 512x512@2x"; do
    set -- $spec
    sips -z "$1" "$1" "$ROOT/build/IconTransparent.png" --out "$ICONSET/icon_$2.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"
SDK="$(xcrun --show-sdk-path)"
swiftc -O -parse-as-library -sdk "$SDK" -target arm64-apple-macos13.0 \
  "$ROOT/WhatsCop/ScanEngine.swift" \
  "$ROOT/WhatsCop/HistoryStore.swift" \
  "$ROOT/WhatsCop/ScanDiagnostics.swift" \
  "$ROOT/WhatsCop/ReportModel.swift" \
  "$ROOT/WhatsCop/Components.swift" \
  "$ROOT/WhatsCop/WhatsCopApp.swift" \
  -o "$APP/Contents/MacOS/WhatsCop"
codesign --force -s - "$APP"
echo "Built $APP"
