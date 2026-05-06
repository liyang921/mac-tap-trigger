#!/bin/bash
# Generic mac-tap-trigger runner.
# Invoked by launchd when a new file appears in the watched iCloud folder.
# Argv: <trigger-name> <command-to-eval>

NAME="$1"
COMMAND="$2"

if [ -z "$NAME" ] || [ -z "$COMMAND" ]; then
    echo "mac-tap-trigger: missing argv (name + command)" >&2
    exit 2
fi

TRIGGER_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Triggers/$NAME"
LOG="/tmp/${NAME}-trigger.log"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] watcher fired ($NAME)" >> "$LOG"

# launchd may fire before iCloud finishes syncing the folder contents in,
# so poll for up to 10s before giving up.
shopt -s nullglob
files=()
for i in {1..20}; do
    files=("$TRIGGER_DIR"/*)
    [ ${#files[@]} -gt 0 ] && break
    sleep 0.5
done
shopt -u nullglob

if [ ${#files[@]} -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] no trigger file after 10s wait, ignoring" >> "$LOG"
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] running: $COMMAND" >> "$LOG"
eval "$COMMAND"
RC=$?
echo "[$(date '+%Y-%m-%d %H:%M:%S')] action done (exit=$RC)" >> "$LOG"

rm -rf "$TRIGGER_DIR"/*
echo "[$(date '+%Y-%m-%d %H:%M:%S')] cleaned trigger files" >> "$LOG"
