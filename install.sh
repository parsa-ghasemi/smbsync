#!/bin/bash

set -e

echo "🔧 Configuring SMB Sync..."

read -rp "Enter SMB share (e.g. //192.168.1.100/myshare): " SMB_SHARE
read -rp "Enter mount point (default: ~/smbmount): " MOUNT_POINT
MOUNT_POINT=${MOUNT_POINT:-$HOME/smbmount}

read -rp "Enter local sync path (default: ~/smbsync-local): " LOCAL_SYNC
LOCAL_SYNC=${LOCAL_SYNC:-$HOME/smbsync-local}

read -rp "Enter SMB username: " SMB_USERNAME
read -rsp "Enter SMB password: " SMB_PASSWORD
echo ""

CONFIG_DIR="$HOME/.smbsync"
mkdir -p "$CONFIG_DIR"

# Save configuration
cat <<EOF > "$CONFIG_DIR/config.env"
SMB_SHARE="$SMB_SHARE"
MOUNT_POINT="$MOUNT_POINT"
LOCAL_SYNC="$LOCAL_SYNC"
SMB_USERNAME="$SMB_USERNAME"
SMB_PASSWORD="$SMB_PASSWORD"
EOF

# Define a fixed hostname for Unison to avoid archive mismatch
echo 'export UNISONLOCALHOSTNAME=smbsync-host' > "$CONFIG_DIR/env.sh"

# Create mount script
cat <<'EOF' > "$CONFIG_DIR/mount.sh"
#!/bin/bash
source "$(dirname "$0")/config.env"
mkdir -p "$MOUNT_POINT"

mountpoint -q "$MOUNT_POINT" || {
  echo "Mounting SMB share $SMB_SHARE to $MOUNT_POINT..."
  echo "$SMB_PASSWORD" | sudo -S mount -t cifs "$SMB_SHARE" "$MOUNT_POINT" -o username="$SMB_USERNAME",password="$SMB_PASSWORD",uid=$(id -u),gid=$(id -g)
}
EOF
chmod +x "$CONFIG_DIR/mount.sh"

# Create chmod watcher
cat <<'EOF' > "$CONFIG_DIR/autochmod.sh"
#!/bin/bash
source "$(dirname "$0")/config.env"
inotifywait -m -r -e create "$MOUNT_POINT" --format '%w%f' | while read -r file; do
  chmod 755 "$file"
  echo "chmod 755 $file" >> "$CONFIG_DIR/autochmod.log"
done
EOF
chmod +x "$CONFIG_DIR/autochmod.sh"

# Create unison sync script
cat <<'EOF' > "$CONFIG_DIR/unison-sync.sh"
#!/bin/bash
source "$(dirname "$0")/config.env"
source "$(dirname "$0")/env.sh"

"$CONFIG_DIR/mount.sh"

mkdir -p "$LOCAL_SYNC"

echo "Running Unison sync..."
unison "$MOUNT_POINT" "$LOCAL_SYNC" -auto -batch -log=true -logfile "$CONFIG_DIR/unison.log" -ignore 'Path .Trash*'
EOF
chmod +x "$CONFIG_DIR/unison-sync.sh"

# Add to cron (every 5 min)
(crontab -l 2>/dev/null | grep -v "$CONFIG_DIR/unison-sync.sh" ; echo "*/5 * * * * bash \"$CONFIG_DIR/unison-sync.sh\"") | crontab -

echo "✅ SMB Sync setup completed!"
echo "📁 Config stored in $CONFIG_DIR"
