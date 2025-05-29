#!/bin/bash

echo "Starting uninstallation of SMB Sync and AutoChmod services..."

# Define important directories and files (modify if you used different paths)
SMBSYNC_DIR="$HOME/.smbsync"
LOCAL_FOLDER="${HOME}/onlinedata"
CRON_CMD="$SMBSYNC_DIR/unison-sync.sh"

echo "Removing cron job for unison-sync.sh..."

# Remove the cron job related to unison-sync.sh
crontab -l 2>/dev/null | grep -v -F "$CRON_CMD" | crontab -

echo "Stopping autochmod.sh process if running..."

# Kill any running autochmod.sh processes
pkill -f "autochmod.sh" && echo "autochmod.sh process stopped." || echo "No running autochmod.sh process found."

echo "Deleting SMB Sync directory and contents..."
rm -rf "$SMBSYNC_DIR"

echo "Deleting local sync folder..."
rm -rf "$LOCAL_FOLDER"

echo "Cleaning up log files if any..."
rm -f "$HOME/.smbsync/unison.log" "$HOME/.smbsync/autochmod.log"

echo "If you mounted any mount points manually, consider removing them separately if no longer needed."

echo "Uninstallation completed successfully."
