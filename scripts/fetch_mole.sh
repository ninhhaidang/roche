#!/usr/bin/env bash
set -e

# Lấy binary mo hiện có từ Homebrew (hoặc tải trực tiếp từ GitHub release)
if command -v mo &> /dev/null; then
    MO_PATH=$(which mo)
    echo "Found local mo at: $MO_PATH"
    cp "$MO_PATH" bin/mo
    chmod +x bin/mo
    echo "Copied to bin/mo successfully."
else
    echo "Error: 'mo' is not installed locally. Run: brew install mole"
    exit 1
fi
