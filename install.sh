#!/bin/bash

set -e

# === Create required folders ===
CONFIG_DIR="$HOME/.smbsync"
mkdir -p "$CONFIG_DIR"
cd "$CONFIG_DIR"

# === Config file ===
CONFIG_FILE="$CONFIG_DIR/config.env"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "🔧 Configuring SMB Sync..."
  read -p "Enter SMB share (e.g. //192.168.1.100/myshare): " smb_share
  read -p "Enter mount point (default: ~/smbmount): " mount_path
  mount_path="${mount_path:-$HOME/smbmount}"
  read -p "Enter local sync path (default: ~/smbsync-local): " local_path
  local_path="${local_path:-$HOME/smbsync-local}"
  read -p "Enter SMB username: " smb_user
  read -s -p "Enter SMB password: " smb_pass
  echo

  mkdir -p "$mount_path"
  mkdir -p "$local_path"

  cat <<EOF > "$CONFIG_FILE"
SMB_SHARE="$smb_share"
MOUNT_PATH="$mount_path"
LOCAL_PATH="$local_path"
USERNAME="$smb_user"
PASSWORD="$smb_pass"
EOF
else
  echo "✅ Using existing config at $CONFIG_FILE"
fi

source "$CONFIG_FILE"

# === mount.sh ===
cat <<EOF > "$CONFIG_DIR/mount.sh"
#!/bin/bash
source "\$HOME/.smbsync/config.env"

mkdir -p "\$MOUNT_PATH"
if ! mountpoint -q "\$MOUNT_PATH"; then
  mount -t cifs "\$SMB_SHARE" "\$MOUNT_PATH" -o username=\$USERNAME,password=\$PASSWORD || {
    echo "❌ Failed to mount SMB share."
    exit 1
  }
fi
EOF
chmod +x "$CONFIG_DIR/mount.sh"

# === unison-sync.sh ===
cat <<EOF > "$CONFIG_DIR/unison-sync.sh"
#!/bin/bash
source "\$HOME/.smbsync/config.env"

"\$HOME/.smbsync/mount.sh"

unison "\$MOUNT_PATH" "\$LOCAL_PATH" -batch -logfile "\$HOME/.smbsync/unison.log"
EOF
chmod +x "$CONFIG_DIR/unison-sync.sh"

# === autochmod.sh ===
cat <<EOF > "$CONFIG_DIR/autochmod.sh"
#!/bin/bash
source "\$HOME/.smbsync/config.env"

inotifywait -mrq -e create --format '%w%f' "\$LOCAL_PATH" | while read NEWFILE; do
  chmod 755 "\$NEWFILE"
  echo "[\$(date)] chmod 755 \$NEWFILE" >> "\$HOME/.smbsync/autochmod.log"
done
EOF
chmod +x "$CONFIG_DIR/autochmod.sh"

# === Setup cron job ===
(crontab -l 2>/dev/null; echo "*/5 * * * * $CONFIG_DIR/unison-sync.sh") | crontab -u "$USER" -

# Run autochmod in background
pkill -f "$CONFIG_DIR/autochmod.sh" 2>/dev/null || true
nohup "$CONFIG_DIR/autochmod.sh" >/dev/null 2>&1 &

# === Done ===
echo "✅ SMB Sync setup complete. Syncing every 5 minutes via cron."
echo "Logs: \$HOME/.smbsync/unison.log, autochmod.log"
