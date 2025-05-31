#!/bin/bash
set -euo pipefail

echo "🔧 Configuring SMB Sync..."

WORKDIR="$HOME/.smbsync"
mkdir -p "$WORKDIR"

read -rp "Enter SMB share (e.g. //192.168.1.100/myshare): " SMB_SHARE
read -rp "Enter mount point (default: $HOME/smbmount): " MOUNT_POINT
MOUNT_POINT=${MOUNT_POINT:-"$HOME/smbmount"}
read -rp "Enter local sync path (default: $HOME/smbsync-local): " LOCAL_SYNC
LOCAL_SYNC=${LOCAL_SYNC:-"$HOME/smbsync-local"}
read -rp "Enter SMB username: " SMB_USER
read -rsp "Enter SMB password: " SMB_PASS
echo ""

cat > "$WORKDIR/config.env" <<EOF
SMB_SHARE="$SMB_SHARE"
MOUNT_POINT="$MOUNT_POINT"
LOCAL_SYNC="$LOCAL_SYNC"
SMB_USER="$SMB_USER"
SMB_PASS="$SMB_PASS"
EOF

mkdir -p "$MOUNT_POINT"
mkdir -p "$LOCAL_SYNC"

# --- mount.sh ---
cat > "$WORKDIR/mount.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
source "$HOME/.smbsync/config.env"

if mountpoint -q "$MOUNT_POINT"; then
  echo "SMB share is already mounted."
else
  echo "Mounting SMB share $SMB_SHARE to $MOUNT_POINT ..."
  sudo mount -t cifs "$SMB_SHARE" "$MOUNT_POINT" -o username="$SMB_USER",password="$SMB_PASS",rw,uid=$(id -u),gid=$(id -g),file_mode=0664,dir_mode=0775
fi
EOF
chmod +x "$WORKDIR/mount.sh"

# --- autochmod.sh ---
cat > "$WORKDIR/autochmod.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
source "$HOME/.smbsync/config.env"

echo "Fixing permissions inside $LOCAL_SYNC ..."
find "$LOCAL_SYNC" -type f -exec chmod 755 {} +
EOF
chmod +x "$WORKDIR/autochmod.sh"

# --- unison-sync.sh ---
cat > "$WORKDIR/unison-sync.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
cd "$HOME"
source "$HOME/.smbsync/config.env"

# Mount if needed
sudo "$HOME/.smbsync/mount.sh"

# Fix permissions before syncing
bash "$HOME/.smbsync/autochmod.sh"

# Sync
echo "Running Unison sync..."
unison "$MOUNT_POINT" "$LOCAL_SYNC" -auto -batch -logfile "$HOME/.smbsync/unison.log"
EOF
chmod +x "$WORKDIR/unison-sync.sh"

# --- log files ---
touch "$WORKDIR/unison.log"
chmod 644 "$WORKDIR/unison.log"

# --- cron job ---
CRON_CMD="bash $WORKDIR/unison-sync.sh >> $WORKDIR/unison.log 2>&1"
CRON_JOB="*/5 * * * * $CRON_CMD"
(crontab -l 2>/dev/null | grep -Fv "$WORKDIR/unison-sync.sh" ; echo "$CRON_JOB") | crontab -

echo "✅ SMB Sync setup completed!"
echo "📁 Files saved in $WORKDIR"
echo "⏰ Sync scheduled every 5 minutes."
