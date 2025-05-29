#!/bin/bash

echo "🧹 Uninstalling SMB Sync..."

CONFIG_DIR="$HOME/.smbsync"
CONFIG_FILE="$CONFIG_DIR/config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ No installation found."
  exit 1
fi

# Load config
source "$CONFIG_FILE"

# Remove cron job
(crontab -l | grep -v 'unison-sync.sh' | grep -v 'autochmod.sh') | crontab -

# Remove sync folder if it exists and user confirms
if [[ -d "$LOCAL_SYNC_PATH" ]]; then
  read -p "⚠️ Do you want to delete your local sync folder at $LOCAL_SYNC_PATH? [y/N]: " confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    rm -rf "$LOCAL_SYNC_PATH"
    echo "🗑️ Removed $LOCAL_SYNC_PATH"
  else
    echo "ℹ️ Kept $LOCAL_SYNC_PATH"
  fi
fi

# Remove config directory
rm -rf "$CONFIG_DIR"
echo "✅ Uninstall complete."
