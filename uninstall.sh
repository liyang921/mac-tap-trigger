#!/bin/bash
# Remove a mac-tap-trigger.
#
# Usage: ./uninstall.sh <trigger-name>

set -euo pipefail

NAME="${1:-}"
if [ -z "$NAME" ]; then
    echo "Usage: $0 <trigger-name>" >&2
    exit 1
fi

LABEL="local.${NAME}-trigger"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Triggers/$NAME"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true

if [ -f "$PLIST_PATH" ]; then
    rm -f "$PLIST_PATH"
    echo "Removed $PLIST_PATH"
else
    echo "No plist at $PLIST_PATH (already gone)"
fi

echo "Left in place (delete manually if desired):"
echo "  iCloud folder: $ICLOUD_DIR"
echo "  shared runner: ~/.local/bin/mac-tap-trigger.sh  (used by all triggers)"
echo "  log files:     /tmp/${NAME}-trigger*.log"
