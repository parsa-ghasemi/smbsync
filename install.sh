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

# Read password silently
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
# Checks if SMB share is mounted, mounts if not
# ----------------------------------------
cat > "$WORKDIR/mount.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

# Load config variables
source "$HOME/.smbsync/config.env"

# Check if mount point is already mounted
if mountpoint -q "$MOUNT_POINT"; then
  echo "SMB share is already mounted."
else
  echo "Mounting SMB share $SMB_SHARE to $MOUNT_POINT ..."
  # Mount SMB share with user credentials and proper permissions
  sudo mount -t cifs "$SMB_SHARE" "$MOUNT_POINT" -o username="$SMB_USER",password="$SMB_PASS",rw,uid=$(id -u),gid=$(id -g),file_mode=0664,dir_mode=0775
fi
EOF
chmod +x "$WORKDIR/mount.sh"

# ----------------------------------------
# Create unison-sync.sh
# Mount SMB share (if needed) then run Unison sync
# ----------------------------------------
cat > "$WORKDIR/unison-sync.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

# Load config variables
source "$HOME/.smbsync/config.env"

# Run mount script to ensure SMB is mounted
"$HOME/.smbsync/mount.sh"

echo "Running Unison sync..."

# Run unison two-way sync, auto accept, batch mode, log output
unison "$MOUNT_POINT" "$LOCAL_SYNC" -auto -batch -logfile "$HOME/.smbsync/unison.log"
EOF
chmod +x "$WORKDIR/unison-sync.sh"

# ----------------------------------------
# Create autochmod.sh
# Watches local sync folder and fixes permissions on new files
# ----------------------------------------
cat > "$WORKDIR/autochmod.sh" <<'EOF'
#!/bin/bash
set -euo pipefail

# Load config variables
source "$HOME/.smbsync/config.env"

echo "Starting auto chmod watcher on $LOCAL_SYNC"

# Monitor create events recursively and chmod new files
inotifywait -m -r -e create --format '%w%f' "$LOCAL_SYNC" | while read -r NEWFILE
do
  echo "$(date '+%Y-%m-%d %H:%M:%S') Fixing permissions for $NEWFILE" >> "$HOME/.smbsync/autochmod.log"
  chmod 755 "$NEWFILE"
done
EOF
chmod +x "$WORKDIR/autochmod.sh"

# ----------------------------------------
# Create empty log files with proper permissions
# ----------------------------------------
touch "$WORKDIR/unison.log" "$WORKDIR/autochmod.log"
chmod 644 "$WORKDIR/"*.log

# ----------------------------------------
# Setup cron job to run unison-sync.sh every 5 minutes
# Avoid duplicating cron entries if script run multiple times
# ----------------------------------------
CRON_CMD="bash $WORKDIR/unison-sync.sh >> $WORKDIR/unison.log 2>&1"
CRON_JOB="*/5 * * * * $CRON_CMD"

# Install cron job safely
(crontab -l 2>/dev/null | grep -Fv "$WORKDIR/unison-sync.sh" ; echo "$CRON_JOB") | crontab -

echo "✅ SMB Sync setup completed!"
echo "📁 Config and scripts stored in $WORKDIR"
echo "⏰ Unison sync scheduled every 5 minutes via cron"
echo "⚠️ Note: Mounting SMB share requires sudo password on first mount."
