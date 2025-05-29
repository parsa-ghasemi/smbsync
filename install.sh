```bash
#!/bin/bash

set -e

# SMB Sync Setup with Unison & Autochmod Installer
# Installs SMB mount, two-way Unison sync,
# autochmod service, and periodic Unison execution via systemd.

# 1. Read configuration from user with defaults
DEFAULT_MOUNT="/mnt/onlinedata"
DEFAULT_DEST="/home/$(whoami)/onlinedata"
DEFAULT_REMOTE="//192.168.1.10/shared"
DEFAULT_CREDS="/etc/smb-credentials"
DEFAULT_WATCH="$DEFAULT_DEST"

read -rp "Enter mount point path [${DEFAULT_MOUNT}]: " MOUNT_POINT
MOUNT_POINT=${MOUNT_POINT:-$DEFAULT_MOUNT}

read -rp "Enter local mirror path [${DEFAULT_DEST}]: " DEST
DEST=${DEST:-$DEFAULT_DEST}

read -rp "Enter remote SMB address [${DEFAULT_REMOTE}]: " REMOTE
REMOTE=${REMOTE:-$DEFAULT_REMOTE}

read -rp "Enter path to SMB credentials file [${DEFAULT_CREDS}]: " CREDENTIALS
CREDENTIALS=${CREDENTIALS:-$DEFAULT_CREDS}

read -rp "Enter folder path to watch for autochmod [${DEFAULT_WATCH}]: " WATCH_DIR
WATCH_DIR=${WATCH_DIR:-$DEFAULT_WATCH}

# Derived variables
SOURCE="$MOUNT_POINT/"
LOG="$DEST/sync_smb.log"
USER_HOME="/home/$(whoami)"

# 2. Create directories
sudo mkdir -p "$MOUNT_POINT"
mkdir -p "$DEST"
mkdir -p "$USER_HOME/.unison"

# 3. Generate Unison profile
cat <<EOF > "$USER_HOME/.unison/cloudsync.prf"
root = $DEST
root = $MOUNT_POINT
auto = true
batch = true
prefer = newer
log = true
logfile = $USER_HOME/unison_sync.log
EOF

# 4. Create mount & sync script
cat <<EOF > "$USER_HOME/smbsync.sh"
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

# 5. Create autochmod script
cat <<EOF > "$USER_HOME/autochmod.sh"
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

# 6. Create system-wide systemd services
# Use cat | sudo tee to avoid redirection fd issues

# Autochmod service
sudo bash -c "cat <<EOF | tee /etc/systemd/system/autochmod.service
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
EOF"

# Unison sync service and timer
sudo bash -c "cat <<EOF | tee /etc/systemd/system/unison-sync.service
[Unit]
Description=One-shot Unison sync between $DEST and $MOUNT_POINT
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/unison cloudsync
User=$(whoami)
EOF"

sudo bash -c "cat <<EOF | tee /etc/systemd/system/unison-sync.timer
[Unit]
Description=Run Unison sync every 5 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF"

# 7. Reload and enable services
sudo systemctl daemon-reload
sudo systemctl enable autochmod.service
sudo systemctl start autochmod.service
sudo systemctl enable unison-sync.timer
sudo systemctl start unison-sync.timer

# 8. Final instructions
echo "Setup complete!"
echo "- SMB mount and sync available via: $USER_HOME/smbsync.sh"
echo "- Autochmod service: autochmod.service"
echo "- Unison timer: unison-sync.timer (runs every 5 minutes)"
echo "Check logs at $LOG and $USER_HOME/unison_sync.log"
```
