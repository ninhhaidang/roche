#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export DEVELOPER_DIR

echo "Building Roche (Debug)..."
xcodebuild \
  -project Roche/Roche.xcodeproj \
  -scheme Roche \
  -configuration Debug \
  -derivedDataPath build/DerivedData \
  build

echo "Build successful! Artifact at: build/DerivedData/Build/Products/Debug/Roche.app"
