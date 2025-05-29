#!/bin/bash

# Interactive installer for smb-sync setup

echo "== SMB-Sync Setup =="

# Get variables
read -p "Local mirror path (e.g., /home/user/onlinedata): " LOCAL_PATH
read -p "SMB mount point (e.g., /mnt/onlinedata): " MOUNT_POINT
read -p "Remote SMB address (e.g., //192.168.1.100/share): " REMOTE
read -p "Path to smb credentials file (e.g., /etc/smb-credentials): " CREDENTIALS

# Make folders
mkdir -p "$LOCAL_PATH"
sudo mkdir -p "$MOUNT_POINT"

# Setup Unison profile
mkdir -p ~/.unison
cat > ~/.unison/cloudsync.prf <<EOF
root = $LOCAL_PATH
root = $MOUNT_POINT

auto = true
batch = true
prefer = newer
log = true
logfile = $LOCAL_PATH/unison_sync.log
EOF

# Setup autochmod script
cat > ~/autochmod.sh <<EOF
#!/bin/bash
inotifywait -m -r -e create --format '%w%f' "$LOCAL_PATH" | while read FILE; do
    if [ -f "\$FILE" ]; then
        chmod 775 "\$FILE"
    fi
done
EOF

chmod +x ~/autochmod.sh

# Setup systemd service
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/autochmod.service <<EOF
[Unit]
Description=Auto chmod 775 on created files

[Service]
ExecStart=/bin/bash /home/$USER/autochmod.sh
Restart=always

[Install]
WantedBy=default.target
EOF

# Enable systemd user service
systemctl --user daemon-reexec
systemctl --user daemon-reload
systemctl --user enable autochmod.service
systemctl --user start autochmod.service

echo "✅ Autochmod systemd service set up."

echo "Setup complete!"
echo "Now use 'unison cloudsync' to sync files manually."
