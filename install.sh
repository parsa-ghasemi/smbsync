#!/bin/bash

# Start script for setting up SMB sync and auto-chmod tool
# This script will prompt for configuration and then set up the necessary scripts and cron jobs.
# Exit on any error
set -e

echo "Starting setup for SMB sync and auto-chmod tool..."

echo "Checking dependencies..."
if ! command -v unison >/dev/null 2>&1; then
    echo "Error: Unison is not installed. Install it (e.g. sudo apt-get install unison)."
    exit 1
fi
if ! command -v inotifywait >/dev/null 2>&1; then
    echo "Error: inotifywait is not installed. Install inotify-tools (e.g. sudo apt-get install inotify-tools)."
    exit 1
fi
if ! command -v mount >/dev/null 2>&1; then
    echo "Error: mount command not found."
    exit 1
fi
echo "Dependencies are satisfied."

read -e -p "Enter SMB mount point path [/mnt/onlinedata]: " mount_point
mount_point="${mount_point:-/mnt/onlinedata}"
read -e -p "Enter local mirror folder [${HOME}/onlinedata]: " local_folder
local_folder="${local_folder:-${HOME}/onlinedata}"
read -e -p "Enter remote SMB share address [//server/share]: " remote_share
remote_share="${remote_share:-//server/share}"
read -e -p "Enter path to credentials file [/etc/smb-credentials]: " credentials_file
credentials_file="${credentials_file:-/etc/smb-credentials}"
read -e -p "Enter directory to watch for permission fixing [${local_folder}]: " watch_dir
watch_dir="${watch_dir:-$local_folder}"

echo
echo "Configuration:"
echo "  SMB mount point: $mount_point"
echo "  Local mirror folder: $local_folder"
echo "  Remote SMB share: $remote_share"
echo "  Credentials file: $credentials_file"
echo "  Watch directory: $watch_dir"

echo "Creating ~/.smbsync directory..."
mkdir -p "$HOME/.smbsync"
echo "Created ~/.smbsync."

if [ ! -d "$local_folder" ]; then
    echo "Creating local mirror directory $local_folder..."
    mkdir -p "$local_folder"
    echo "Created $local_folder."
else
    echo "Local mirror directory $local_folder already exists."
fi

if [ ! -d "$watch_dir" ]; then
    echo "Creating watch directory $watch_dir..."
    mkdir -p "$watch_dir"
    echo "Created $watch_dir."
else
    echo "Watch directory $watch_dir already exists."
fi

if [ ! -d "$mount_point" ]; then
    echo "Creating SMB mount point directory $mount_point... (requires sudo)"
    sudo mkdir -p "$mount_point"
    echo "Created mount point $mount_point."
else
    echo "Mount point directory $mount_point already exists."
fi

echo "Creating unison-sync script..."
cat > "$HOME/.smbsync/unison-sync.sh" <<EOF
#!/bin/bash

# Unison sync script to synchronize SMB share and local directory
MOUNT_POINT="$mount_point"
LOCAL_FOLDER="$local_folder"
REMOTE_SHARE="$remote_share"
CREDENTIALS_FILE="$credentials_file"
UNISON_PROFILE="smbsync"

# Ensure local folder exists
if [ ! -d "$LOCAL_FOLDER" ]; then
    mkdir -p "$LOCAL_FOLDER"
fi

# Ensure mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    sudo mkdir -p "$MOUNT_POINT"
fi

# Mount remote SMB share if not already mounted
if ! mountpoint -q "$MOUNT_POINT"; then
    echo "Mounting SMB share $REMOTE_SHARE to $MOUNT_POINT..."
    sudo mount -t cifs "$REMOTE_SHARE" "$MOUNT_POINT" -o credentials="$CREDENTIALS_FILE",rw
    if [ $? -ne 0 ]; then
        echo "Error: failed to mount $REMOTE_SHARE"
        exit 1
    fi
    echo "Mounted $REMOTE_SHARE."
else
    echo "SMB share already mounted at $MOUNT_POINT."
fi

# Run Unison synchronization
echo "Running Unison sync..."
unison "$UNISON_PROFILE"
EOF
chmod +x "$HOME/.smbsync/unison-sync.sh"
echo "Created unison-sync.sh and made it executable."

echo "Creating autochmod script..."
cat > "$HOME/.smbsync/autochmod.sh" <<EOF
#!/bin/bash

# Auto chmod script to watch directory and set permissions to 775
WATCH_DIR="$watch_dir"

echo "Starting auto chmod watcher on $WATCH_DIR..."
inotifywait -m -r -e create --format '%w%f' "$WATCH_DIR" | while read NEWFILE
do
    echo "Setting permissions 775 on $NEWFILE"
    chmod 775 "$NEWFILE"
done
EOF
chmod +x "$HOME/.smbsync/autochmod.sh"
echo "Created autochmod.sh and made it executable."

echo "Creating Unison profile..."
mkdir -p "$HOME/.unison"
cat > "$HOME/.unison/smbsync.prf" <<EOF
root = $local_folder
root = $mount_point
logfile = $HOME/.smbsync/unison.log
batch = true
auto = true
EOF
echo "Created Unison profile at ~/.unison/smbsync.prf."

echo "Setting up cron job to run unison-sync every 5 minutes..."
croncmd="$HOME/.smbsync/unison-sync.sh"
cronjob="*/5 * * * * $croncmd"
(crontab -l 2>/dev/null | grep -Fv "$croncmd"; echo "$cronjob") | crontab -
echo "Cron job added: $cronjob"

echo "Starting autochmod.sh as a background service..."
if ! pgrep -f "autochmod.sh" >/dev/null 2>&1; then
    nohup bash "$HOME/.smbsync/autochmod.sh" >> "$HOME/.smbsync/autochmod.log" 2>&1 &
    echo "autochmod.sh started (logging to ~/.smbsync/autochmod.log)."
else
    echo "autochmod.sh is already running. Skipping start."
fi

echo "Setup complete. Enjoy your SMB sync and auto-chmod tools!"
