#!/usr/bin/env bash
set -euo pipefail

TARGET_BIN="/tmp/roche_tests_$(date +%s)"
echo "Building Roche Core + Test suite..."
swiftc -target arm64-apple-macos14.0 -parse-as-library \
  $(find Roche/Roche/Core -name "*.swift") \
  $(find Tests -name "*.swift") \
  -o "$TARGET_BIN"

echo "Executing Roche test suite..."
"$TARGET_BIN"
rm -f "$TARGET_BIN"
