#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
APP="$ROOT/build/WhatsCop.app"
mkdir -p "$ROOT/build"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$ROOT/WhatsCop/Info.plist" "$APP/Contents/Info.plist"
SDK="$(xcrun --show-sdk-path)"
swiftc -O -parse-as-library -sdk "$SDK" -target arm64-apple-macos13.0 \
  "$ROOT/WhatsCop/ScanEngine.swift" "$ROOT/WhatsCop/WhatsCopApp.swift" \
  -o "$APP/Contents/MacOS/WhatsCop"
codesign --force -s - "$APP"
echo "Built $APP"
