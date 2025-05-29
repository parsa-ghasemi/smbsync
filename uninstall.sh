#!/bin/bash

echo "Stopping and disabling systemd user services..."
systemctl --user stop autochmod.service unison-sync.timer unison-sync.service || true
systemctl --user disable autochmod.service unison-sync.timer unison-sync.service || true
systemctl --user daemon-reload

echo "Removing systemd user service files..."
rm -f "$HOME/.config/systemd/user/autochmod.service" \
      "$HOME/.config/systemd/user/unison-sync.service" \
      "$HOME/.config/systemd/user/unison-sync.timer"

echo "Removing scripts..."
rm -f "$HOME/autochmod.sh" "$HOME/smbsync.sh"

echo "Keeping data files and logs intact:"
echo " - Local mirror folder (e.g. $HOME/onlinedata)"
echo " - Unison profile (e.g. $HOME/.unison/cloudsync.prf)"
echo " - Logs (e.g. $HOME/unison_sync.log, sync_smb.log)"

echo "Uninstallation complete."
