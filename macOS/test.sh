#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SDK="$(xcrun --show-sdk-path)"
NATIVE="$(mktemp -t whatscop-scan-tests)"
HISTORY="$(mktemp -t whatscop-history-tests)"
trap 'rm -f "$NATIVE" "$HISTORY"' EXIT
swiftc -parse-as-library -sdk "$SDK" -target arm64-apple-macos13.0 \
  "$ROOT/WhatsCop/ScanEngine.swift" "$ROOT/Tests/ScanEngineTests.swift" -o "$NATIVE"
"$NATIVE" "$@"
swiftc -parse-as-library -sdk "$SDK" -target arm64-apple-macos13.0 \
  "$ROOT/WhatsCop/ScanEngine.swift" "$ROOT/WhatsCop/HistoryStore.swift" \
  "$ROOT/Tests/HistoryStoreTests.swift" -o "$HISTORY"
"$HISTORY"
