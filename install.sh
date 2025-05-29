```bash
#!/bin/bash

set -e

# SMB Sync Setup with Unison & Autochmod Installer
# This script installs and configures SMB mounting, two-way Unison sync,
# autochmod service, and periodic Unison execution via systemd.

# 1. Read configuration from user
read -rp "Enter mount point path (e.g. /mnt/onlinedata): " MOUNT_POINT
read -rp "Enter local mirror path (e.g. /home/$(whoami)/onlinedata): " DEST
read -rp "Enter remote SMB address (e.g. //192.168.1.10/shared): " REMOTE
read -rp "Enter path to SMB credentials file (e.g. /etc/smb-credentials): " CREDENTIALS
read -rp "Enter folder path to watch for autochmod (e.g. /home/$(whoami)/onlinedata): " WATCH_DIR

# Derived variables
SOURCE="$MOUNT_POINT/"
LOG="$DEST/sync_smb.log"
USER_HOME="/home/$(whoami)"

# 2. Install dependencies
sudo apt update
sudo apt install -y cifs-utils rsync inotify-tools unison

# 3. Create directories
sudo mkdir -p "$MOUNT_POINT"
mkdir -p "$DEST"
mkdir -p "$USER_HOME/.unison"

# 4. Generate Unison profile
cat > "$USER_HOME/.unison/cloudsync.prf" <<EOF
root = $DEST
root = $MOUNT_POINT
auto = true
batch = true
prefer = newer
log = true
logfile = $USER_HOME/unison_sync.log
EOF

# 5. Create mount & sync script
cat > "$USER_HOME/smbsync.sh" <<EOF
#!/bin/bash
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "[\$(date)] Mount not active. Attempting to mount..." >> "$LOG"
    sudo mount -t cifs -o credentials=$CREDENTIALS,iocharset=utf8,uid=$(id -u),gid=$(id -g),file_mode=0775,dir_mode=0775 "$REMOTE" "$MOUNT_POINT"
    sleep 2
fi
if mountpoint -q "$MOUNT_POINT"; then
    echo "[\$(date)] Mount successful. Starting sync..." >> "$LOG"
    rsync -av --delete "$SOURCE" "$DEST" >> "$LOG" 2>&1
else
    echo "[\$(date)] Mount failed. Skipping sync." >> "$LOG"
fi
EOF

chmod +x "$USER_HOME/smbsync.sh"

# 6. Create autochmod script
cat > "$USER_HOME/autochmod.sh" <<EOF
#!/bin/bash
# Watch folder and chmod new/modified files to 775
echo "Starting autochmod on $WATCH_DIR"
inotifywait -m -r -e create -e modify --format '%w%f' "$WATCH_DIR" | while read FILE; do
    if [ -f "$FILE" ]; then
        chmod 775 "$FILE"
        echo "[\$(date)] Set 775 on: $FILE" >> "$WATCH_DIR/chmod_watch.log"
    fi
done
EOF
chmod +x "$USER_HOME/autochmod.sh"

# 7. Create system-wide systemd services

# Autochmod service
autochmod_unit="/etc/systemd/system/autochmod.service"
sudo tee "$autochmod_unit" > /dev/null <<EOF
[Unit]
Description=Auto chmod on new files in $WATCH_DIR
After=network.target

[Service]
ExecStart=$USER_HOME/autochmod.sh
Restart=always
RestartSec=10
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

# Unison sync service and timer
unison_service="/etc/systemd/system/unison-sync.service"
sudo tee "$unison_service" > /dev/null <<EOF
[Unit]
Description=One-shot Unison sync between $DEST and $MOUNT_POINT
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/unison cloudsync
User=$(whoami)
EOF

unison_timer="/etc/systemd/system/unison-sync.timer"
sudo tee "$unison_timer" > /dev/null <<EOF
[Unit]
Description=Run Unison sync every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# 8. Reload and enable services
sudo systemctl daemon-reload
sudo systemctl enable autochmod.service
sudo systemctl start autochmod.service
sudo systemctl enable unison-sync.timer
sudo systemctl start unison-sync.timer

# 9. Final instructions
echo "Setup complete!"
echo "- SMB mount and sync available via: $USER_HOME/smbsync.sh"
echo "- Autochmod service: autochmod.service"
echo "- Unison timer: unison-sync.timer (runs every 5 minutes)"
echo "Check logs at $LOG and $USER_HOME/unison_sync.log"
```
