#!/bin/bash
# Install a mac-tap-trigger.
#
# Usage:  ./install.sh <trigger-name> <command>
# Example: ./install.sh teamviewer 'open -a TeamViewer'
#          ./install.sh restart-finder 'killall Finder'

set -euo pipefail

NAME="${1:-}"
COMMAND="${2:-}"

if [ -z "$NAME" ] || [ -z "$COMMAND" ]; then
    cat >&2 <<EOF
Usage: $0 <trigger-name> <command>

  <trigger-name>  alphanumeric + dashes; used in paths and the iPhone Shortcut
  <command>       any shell command; eval'd when the trigger fires

Example:
  $0 teamviewer 'open -a TeamViewer'
  $0 restart-finder 'killall Finder'
EOF
    exit 1
fi

if ! [[ "$NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    echo "Error: trigger name must match [a-zA-Z0-9-]+" >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_SCRIPT="$REPO_DIR/templates/mac-tap-trigger.sh"
TEMPLATE_PLIST="$REPO_DIR/templates/launchagent.plist.template"

if [ ! -f "$TEMPLATE_SCRIPT" ] || [ ! -f "$TEMPLATE_PLIST" ]; then
    echo "Error: templates/ missing — run from inside a checkout of mac-tap-trigger" >&2
    exit 1
fi

LABEL="local.${NAME}-trigger"
RUNNER_PATH="$HOME/.local/bin/mac-tap-trigger.sh"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Triggers/$NAME"

# 1. Install the shared runner (idempotent — same script for every trigger).
mkdir -p "$HOME/.local/bin"
cp "$TEMPLATE_SCRIPT" "$RUNNER_PATH"
chmod +x "$RUNNER_PATH"

# 2. Create the iCloud folder this trigger will watch.
mkdir -p "$ICLOUD_DIR"

# 3. XML-escape the command for safe inclusion in the plist <string>.
xml_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    s="${s//\'/&apos;}"
    printf '%s' "$s"
}
COMMAND_ESC="$(xml_escape "$COMMAND")"

# 4. Render the plist from the template using bash parameter expansion.
# (sed would treat `&` in COMMAND_ESC as a backreference and mangle XML entities.)
mkdir -p "$HOME/Library/LaunchAgents"
template=$(<"$TEMPLATE_PLIST")
template="${template//__LABEL__/$LABEL}"
template="${template//__SCRIPT_PATH__/$RUNNER_PATH}"
template="${template//__NAME__/$NAME}"
template="${template//__WATCH_PATH__/$ICLOUD_DIR}"
template="${template//__COMMAND__/$COMMAND_ESC}"
printf '%s\n' "$template" > "$PLIST_PATH"

# 5. (Re)load the LaunchAgent.
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"

cat <<EOF

Installed trigger: $NAME
  runner    $RUNNER_PATH
  plist     $PLIST_PATH
  watches   $ICLOUD_DIR
  command   $COMMAND

Next steps (one-time):
  1. Grant /bin/bash Full Disk Access:
       System Settings → Privacy & Security → Full Disk Access → add /bin/bash
     (launchd-spawned bash needs FDA to read iCloud Drive — TCC sandbox.)

  2. Disable sleep on AC power:
       sudo pmset -c sleep 0
     (sleep pauses iCloud sync, which breaks the trigger chain.)

  3. On your iPhone, create a Shortcut:
       Action:  New Folder
       Path:    /Triggers/$NAME/trigger
       Service: iCloud Drive
     Add it to the home screen. Tapping it fires the trigger.

To test the chain manually (without the iPhone):
  mkdir "$ICLOUD_DIR/test"
  # ...then check /tmp/${NAME}-trigger.log
EOF
