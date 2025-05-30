#!/bin/bash
set -euo pipefail

# ----------------------------------------
# SMB Sync Installer Script
# Sets up SMB mount, unison sync, permission fixer, and cron job
# ----------------------------------------

echo "🔧 Configuring SMB Sync..."

# Working directory for the app (hidden folder in user's home)
WORKDIR="$HOME/.smbsync"

# Create working directory if it doesn't exist
mkdir -p "$WORKDIR"

# --- User Inputs with defaults ---
read -rp "Enter SMB share (e.g. //192.168.1.100/myshare): " SMB_SHARE
read -rp "Enter mount point (default: $HOME/smbmount): " MOUNT_POINT
MOUNT_POINT=${MOUNT_POINT:-"$HOME/smbmount"}
read -rp "Enter local sync path (default: $HOME/smbsync-local): " LOCAL_SYNC
LOCAL_SYNC=${LOCAL_SYNC:-"$HOME/smbsync-local"}
read -rp "Enter SMB username: " SMB_USER
read -rsp "Enter SMB password: " SMB_PASS
echo ""

# --- Save config variables to file ---
cat > "$WORKDIR/config.env" <<EOF
SMB_SHARE="$SMB_SHARE"
MOUNT_POINT="$MOUNT_POINT"
LOCAL_SYNC="$LOCAL_SYNC"
SMB_USER="$SMB_USER"
SMB_PASS="$SMB_PASS"
EOF

# Create mount point and local sync directories
mkdir -p "$MOUNT_POINT"
mkdir -p "$LOCAL_SYNC"

# ----------------------------------------
# Create mount.sh
# ----------------------------------------
cat > "$WORKDIR/mount.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

# Load config using actual user home
REAL_HOME="/home/$SUDO_USER"
source "$REAL_HOME/.smbsync/config.env"

# Check if already mounted
if mountpoint -q "$MOUNT_POINT"; then
  echo "SMB share is already mounted."
else
  echo "Mounting SMB share $SMB_SHARE to $MOUNT_POINT ..."
  sudo mount -t cifs "$SMB_SHARE" "$MOUNT_POINT" -o username="$SMB_USER",password="$SMB_PASS",rw,uid=$(id -u "$SUDO_USER"),gid=$(id -g "$SUDO_USER"),file_mode=0664,dir_mode=0775
fi
EOF
chmod +x "$WORKDIR/mount.sh"

# ----------------------------------------
# Create unison-sync.sh
# ----------------------------------------
cat > "$WORKDIR/unison-sync.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

source "$HOME/.smbsync/config.env"

# Ensure mounted
sudo "$HOME/.smbsync/mount.sh"

echo "Running Unison sync..."

# Two-way full sync with auto-propagation of new files
unison "$MOUNT_POINT" "$LOCAL_SYNC" -auto -batch -logfile "$HOME/.smbsync/unison.log" -prefer newer -copyonconflict
EOF
chmod +x "$WORKDIR/unison-sync.sh"

# ----------------------------------------
# Create autochmod.sh
# ----------------------------------------
cat > "$WORKDIR/autochmod.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

source "$HOME/.smbsync/config.env"

echo "Starting auto chmod watcher on $LOCAL_SYNC"

inotifywait -m -r -e create --format '%w%f' "$LOCAL_SYNC" | while read -r NEWFILE
do
  echo "$(date '+%Y-%m-%d %H:%M:%S') Fixing permissions for $NEWFILE" >> "$HOME/.smbsync/autochmod.log"
  chmod 755 "$NEWFILE"
done
EOF
chmod +x "$WORKDIR/autochmod.sh"

# ----------------------------------------
# Prepare log files
# ----------------------------------------
touch "$WORKDIR/unison.log" "$WORKDIR/autochmod.log"
chmod 644 "$WORKDIR/"*.log

# ----------------------------------------
# Add cron job
# ----------------------------------------
CRON_CMD="bash $WORKDIR/unison-sync.sh >> $WORKDIR/unison.log 2>&1"
CRON_JOB="*/5 * * * * $CRON_CMD"

# Prevent duplicates
(crontab -l 2>/dev/null | grep -Fv "$WORKDIR/unison-sync.sh" ; echo "$CRON_JOB") | crontab -

echo "✅ SMB Sync setup completed!"
echo "📁 Config and scripts stored in $WORKDIR"
echo "⏰ Unison sync scheduled every 5 minutes via cron"
echo "⚠️ Note: Mounting SMB share requires sudo password on first mount."
