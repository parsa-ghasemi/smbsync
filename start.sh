#!/bin/bash

set -e

# Documentation header
echo """
============================================
  SMB + Unison Sync Auto Installer Script
============================================
This script sets up a mirrored sync between a remote SMB share and a local folder,
with file permission fixing using inotify, and automated syncing via Unison.

It will:
- Install required packages
- Mount SMB share
- Set up Unison profile
- Set up autochmod service (to fix file permissions)
- Set up a cron job to run Unison periodically

Author: YourName
Repo: https://github.com/youruser/smb-unison-sync
"""

# 1. Ask for inputs
read -p "Local username: " LOCAL_USER
read -p "Local mount directory (e.g. /mnt/onlinedata): " MOUNT_POINT
read -p "Local sync target (e.g. /home/$LOCAL_USER/onlinedata): " LOCAL_TARGET
read -p "Remote SMB share (e.g. //ip.example.com/share): " REMOTE_SMB
read -p "SMB username: " SMB_USER
read -sp "SMB password: " SMB_PASS
echo

# 2. Install dependencies
sudo apt update
sudo apt install -y cifs-utils rsync inotify-tools unison

# 3. Create required folders
sudo mkdir -p "$MOUNT_POINT"
mkdir -p "$LOCAL_TARGET"

# 4. Create SMB credentials file
CRED_FILE="/etc/smb-credentials"
echo -e "username=$SMB_USER\npassword=$SMB_PASS" | sudo tee "$CRED_FILE" > /dev/null
sudo chmod 600 "$CRED_FILE"

# 5. Mount SMB share
sudo mount -t cifs -o credentials=$CRED_FILE,iocharset=utf8,uid=$(id -u $LOCAL_USER),gid=$(id -g $LOCAL_USER),file_mode=0775,dir_mode=0775 "$REMOTE_SMB" "$MOUNT_POINT"

# 6. Create Unison profile
UNISON_DIR="/home/$LOCAL_USER/.unison"
mkdir -p "$UNISON_DIR"
cat > "$UNISON_DIR/cloudsync.prf" <<EOF
root = $LOCAL_TARGET
root = $MOUNT_POINT
auto = true
batch = true
prefer = newer
log = true
logfile = /home/$LOCAL_USER/unison_sync.log
EOF

# 7. Create autochmod.sh script
AUTOCHMOD_SCRIPT="/home/$LOCAL_USER/autochmod.sh"
cat > "$AUTOCHMOD_SCRIPT" <<'EOF'
#!/bin/bash
WATCH_DIR="$1"
inotifywait -m -r -e create -e moved_to --format '%w%f' "$WATCH_DIR" | while read NEWFILE; do
    if [ -f "$NEWFILE" ]; then
        chmod 775 "$NEWFILE"
        echo "[$(date)] Set 775 on: $NEWFILE" >> "$WATCH_DIR/chmod_watch.log"
    fi
done
EOF
chmod +x "$AUTOCHMOD_SCRIPT"

# 8. Create systemd service for autochmod
SERVICE_FILE="/etc/systemd/system/autochmod.service"

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=Auto chmod for new files in $LOCAL_TARGET
After=network.target

[Service]
Type=simple
User=$LOCAL_USER
ExecStart=$AUTOCHMOD_SCRIPT $LOCAL_TARGET
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable autochmod.service
sudo systemctl start autochmod.service

# 9. Add Unison to crontab
(crontab -u $LOCAL_USER -l 2>/dev/null; echo "*/5 * * * * unison cloudsync") | crontab -u $LOCAL_USER -

# 10. Done
echo "✅ Setup complete! SMB is mounted, sync is active, and autochmod + cron are running."
