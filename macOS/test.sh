#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BIN="$(mktemp -t whatscop-tests)"
trap 'rm -f "$BIN"' EXIT
SDK="$(xcrun --show-sdk-path)"
swiftc -parse-as-library -sdk "$SDK" -target arm64-apple-macos13.0 \
  "$ROOT/WhatsCop/ScanEngine.swift" "$ROOT/Tests/ScanEngineTests.swift" \
  -o "$BIN"
"$BIN" "$@"
