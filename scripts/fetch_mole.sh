#!/usr/bin/env bash
set -e

# Lấy binary mo hiện có từ Homebrew (hoặc tải trực tiếp từ GitHub release)
if command -v mo &> /dev/null; then
    MO_PATH=$(which mo)
    echo "Found local mo at: $MO_PATH"
    cp "$MO_PATH" bin/mo
    chmod +x bin/mo
    echo "Copied to bin/mo successfully."

    for cellar in /opt/homebrew/Cellar/mole/* /usr/local/Cellar/mole/*; do
        if [ -x "$cellar/libexec/bin/status-go" ]; then
            mkdir -p vendor/mole/bin
            cp "$cellar/libexec/bin/status-go" vendor/mole/bin/
            [ -x "$cellar/libexec/bin/analyze-go" ] && cp "$cellar/libexec/bin/analyze-go" vendor/mole/bin/
            chmod +x vendor/mole/bin/status-go 2>/dev/null || true
            echo "Copied status-go to vendor/mole/bin successfully."
            break
        fi
    done
else
    echo "Error: 'mo' is not installed locally. Run: brew install mole"
    exit 1
fi
