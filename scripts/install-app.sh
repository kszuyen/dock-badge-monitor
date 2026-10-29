#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_PATH="/Applications/BadgeBell.app"
AGENT_LABEL="io.github.kszuyen.badgebell.monitor"
SERVICE="gui/$(id -u)/$AGENT_LABEL"
FIRST_INSTALL=true
if [[ -d "$APP_PATH" ]]; then FIRST_INSTALL=false; fi

"$SCRIPT_DIR/package-app.sh"

STAGING_DIR="$(mktemp -d /Applications/.BadgeBell-install.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "$ROOT_DIR/dist/BadgeBell.app" "$STAGING_DIR/BadgeBell.app"
codesign --verify --deep --strict "$STAGING_DIR/BadgeBell.app"

# Preserve the installed version before replacing it.
if [[ -d "$APP_PATH" ]]; then
  BACKUP_DIR="$HOME/Library/Application Support/BadgeBell/Backups/$(date +%Y%m%d-%H%M%S)-$$"
  mkdir -p "$BACKUP_DIR"
  ditto "$APP_PATH" "$BACKUP_DIR/BadgeBell.app"
  echo "Previous app saved to $BACKUP_DIR"
fi

# Stop only BadgeBell's managed job during an update.
if launchctl print "$SERVICE" >/dev/null 2>&1; then
  launchctl bootout "$SERVICE"
fi
if pgrep -x BadgeBell >/dev/null; then
  echo "Quit the running BadgeBell instance, then run this installer again." >&2
  exit 1
fi

if [[ -d "$APP_PATH" ]]; then mv "$APP_PATH" "$STAGING_DIR/previous.app"; fi
if ! mv "$STAGING_DIR/BadgeBell.app" "$APP_PATH"; then
  if [[ -d "$STAGING_DIR/previous.app" ]]; then mv "$STAGING_DIR/previous.app" "$APP_PATH"; fi
  exit 1
fi
if [[ "$FIRST_INSTALL" == true ]]; then
  "$APP_PATH/Contents/MacOS/BadgeBell" --enable-login
fi
open "$APP_PATH"
echo "Installed and started $APP_PATH"
echo "First installs enable Launch at Login; updates preserve your setting."
