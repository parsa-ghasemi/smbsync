#!/bin/bash

set -e

echo "=== SMB Sync Setup with Unison & Autochmod ==="

read -rp "Enter mount point path (e.g. /mnt/onlinedata): " MOUNT_POINT
read -rp "Enter local mirror path (e.g. /home/$(whoami)/onlinedata): " DEST
read -rp "Enter remote SMB address (e.g. //192.168.1.10/shared): " REMOTE
read -rp "Enter path to SMB credentials file (e.g. /etc/smb-credentials): " CREDENTIALS
read -rp "Enter folder path to watch for autochmod (e.g. /home/$(whoami)/onlinedata): " WATCH_DIR

SOURCE="$MOUNT_POINT/"
LOG="$DEST/sync_smb.log"

echo
echo "Creating mount check and rsync script at $HOME/smbsync.sh"

cat > "$HOME/smbsync.sh" <<EOF
#!/bin/bash
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "[(\$(date))] Mount not active. Attempting to mount..." >> "$LOG"
    sudo mount -t cifs -o credentials=$CREDENTIALS,iocharset=utf8,uid=\$(id -u),gid=\$(id -g),file_mode=0775,dir_mode=0775 "$REMOTE" "$MOUNT_POINT"
    sleep 2
fi

if mountpoint -q "$MOUNT_POINT"; then
    echo "[(\$(date))] Mount successful. Starting sync..." >> "$LOG"
    rsync -av --delete "$SOURCE" "$DEST" >> "$LOG" 2>&1
else
    echo "[(\$(date))] Mount failed. Skipping sync." >> "$LOG"
fi
EOF

chmod +x "$HOME/smbsync.sh"

echo
echo "Creating Unison profile at $HOME/.unison/cloudsync.prf"

mkdir -p "$HOME/.unison"

cat > "$HOME/.unison/cloudsync.prf" <<EOF
root = $DEST
root = $MOUNT_POINT
auto = true
batch = true
prefer = newer
log = true
logfile = $HOME/unison_sync.log
EOF

echo
echo "Creating autochmod.sh script"

cat > "$HOME/autochmod.sh" <<EOF
#!/bin/bash
# Watch the folder and chmod new/modified files to 775

WATCH_DIR="$WATCH_DIR"

inotifywait -m -r -e create -e modify --format '%w%f' "\$WATCH_DIR" | while read FILE
do
    chmod 775 "\$FILE"
done
EOF

chmod +x "$HOME/autochmod.sh"

echo
echo "Creating systemd user service for autochmod"

mkdir -p "$HOME/.config/systemd/user"

cat > "$HOME/.config/systemd/user/autochmod.service" <<EOF
[Unit]
Description=Auto chmod on new files in sync folder
After=network.target

[Service]
ExecStart=$HOME/autochmod.sh
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOF

echo
echo "Creating systemd user service and timer for Unison sync every 5 minutes"

cat > "$HOME/.config/systemd/user/unison-sync.service" <<EOF
[Unit]
Description=Run Unison sync every 5 minutes
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/unison cloudsync
EOF

cat > "$HOME/.config/systemd/user/unison-sync.timer" <<EOF
[Unit]
Description=Timer to run Unison sync every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo
echo "Reloading systemd user daemon and enabling services..."

systemctl --user daemon-reload
systemctl --user enable --now autochmod.service
systemctl --user enable --now unison-sync.timer

echo
echo "Setup complete!"
echo " - Mount check & rsync script: $HOME/smbsync.sh"
echo " - Unison profile: $HOME/.unison/cloudsync.prf"
echo " - Autochmod service: autochmod.service"
echo " - Unison timer: unison-sync.timer (runs every 5 minutes)"
echo
echo "You can check logs:"
echo " - Unison log: $HOME/unison_sync.log"
echo " - SMB sync log: $LOG"
