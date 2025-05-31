#!/bin/bash
set -euo pipefail

echo "🔧 Configuring SMB Sync..."

# Determine real user and home directory (handle sudo and normal run)
if [ -n "${SUDO_USER-}" ]; then
  REAL_USER="$SUDO_USER"
  REAL_HOME=$(eval echo "~$SUDO_USER")
else
  REAL_USER="$USER"
  REAL_HOME="$HOME"
fi

WORKDIR="$REAL_HOME/.smbsync"
mkdir -p "$WORKDIR"

read -rp "Enter SMB share (e.g. //192.168.1.100/myshare): " SMB_SHARE
read -rp "Enter mount point (default: $REAL_HOME/smbmount): " MOUNT_POINT
MOUNT_POINT=${MOUNT_POINT:-"$REAL_HOME/smbmount"}
read -rp "Enter local sync path (default: $REAL_HOME/smbsync-local): " LOCAL_SYNC
LOCAL_SYNC=${LOCAL_SYNC:-"$REAL_HOME/smbsync-local"}
read -rp "Enter SMB username: " SMB_USER
read -rsp "Enter SMB password: " SMB_PASS
echo ""

# Save config
cat > "$WORKDIR/config.env" <<EOF
SMB_SHARE="$SMB_SHARE"
MOUNT_POINT="$MOUNT_POINT"
LOCAL_SYNC="$LOCAL_SYNC"
SMB_USER="$SMB_USER"
SMB_PASS="$SMB_PASS"
EOF

# Create mount and sync directories with correct ownership
mkdir -p "$MOUNT_POINT" "$LOCAL_SYNC"
chown -R "$REAL_USER":"$REAL_USER" "$WORKDIR" "$MOUNT_POINT" "$LOCAL_SYNC"

# Create mount.sh
cat > "$WORKDIR/mount.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

if [ -n "${SUDO_USER-}" ]; then
  REAL_HOME=$(eval echo "~$SUDO_USER")
else
  REAL_HOME="$HOME"
fi

source "$REAL_HOME/.smbsync/config.env"

if mountpoint -q "$MOUNT_POINT"; then
  echo "SMB share is already mounted."
else
  echo "Mounting SMB share $SMB_SHARE to $MOUNT_POINT ..."
  sudo mount -t cifs "$SMB_SHARE" "$MOUNT_POINT" -o username="$SMB_USER",password="$SMB_PASS",rw,uid=$(id -u $SUDO_USER),gid=$(id -g $SUDO_USER),file_mode=0664,dir_mode=0775
fi
EOF
chmod +x "$WORKDIR/mount.sh"

# Create unison-sync.sh
cat > "$WORKDIR/unison-sync.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

if [ -n "${SUDO_USER-}" ]; then
  REAL_HOME=$(eval echo "~$SUDO_USER")
else
  REAL_HOME="$HOME"
fi

source "$REAL_HOME/.smbsync/config.env"

sudo "$REAL_HOME/.smbsync/mount.sh"

echo "Running Unison sync..."

unison "$MOUNT_POINT" "$LOCAL_SYNC" -auto -batch -logfile "$REAL_HOME/.smbsync/unison.log"
EOF
chmod +x "$WORKDIR/unison-sync.sh"

# Create autochmod.sh
cat > "$WORKDIR/autochmod.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

if [ -n "${SUDO_USER-}" ]; then
  REAL_HOME=$(eval echo "~$SUDO_USER")
else
  REAL_HOME="$HOME"
fi

source "$REAL_HOME/.smbsync/config.env"

echo "Starting auto chmod watcher on $LOCAL_SYNC"

inotifywait -m -r -e create -e moved_to -e close_write --format '%w%f' "$LOCAL_SYNC" | while read -r NEWFILE
do
  if [ -f "$NEWFILE" ]; then
    chmod 755 "$NEWFILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Set 755 for file $NEWFILE" >> "$REAL_HOME/.smbsync/autochmod.log"
  elif [ -d "$NEWFILE" ]; then
    chmod 755 "$NEWFILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Set 755 for dir $NEWFILE" >> "$REAL_HOME/.smbsync/autochmod.log"
  fi
done
EOF
chmod +x "$WORKDIR/autochmod.sh"


# Prepare log files
touch "$WORKDIR/unison.log" "$WORKDIR/autochmod.log"
chown "$REAL_USER":"$REAL_USER" "$WORKDIR/"*.log
chmod 644 "$WORKDIR/"*.log

# Setup cron job
CRON_CMD="bash $WORKDIR/unison-sync.sh >> $WORKDIR/unison.log 2>&1"
CRON_JOB="*/5 * * * * $CRON_CMD"

# Add cron job only if not already present
(crontab -u "$REAL_USER" -l 2>/dev/null | grep -Fv "$WORKDIR/unison-sync.sh" ; echo "$CRON_JOB") | crontab -u "$REAL_USER" -

echo "✅ SMB Sync setup completed!"
echo "📁 Config and scripts stored in $WORKDIR"
echo "⏰ Unison sync scheduled every 5 minutes via cron"
echo "⚠️ Note: Mounting SMB share requires sudo password on first mount."
