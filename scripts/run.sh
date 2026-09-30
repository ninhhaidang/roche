#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

APP_PATH="build/DerivedData/Build/Products/Debug/Roche.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Roche.app not found. Building first..."
  ./scripts/build.sh
fi

echo "Opening Roche.app..."
open "$APP_PATH"
echo "Roche is running!"
