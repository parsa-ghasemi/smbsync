#!/bin/bash

# Get input from user
read -p "Enter mount point: " MOUNT_POINT
read -p "Enter local mirror path: " MIRROR_PATH
read -p "Enter remote address (e.g. //server/share): " REMOTE_ADDR
read -p "Enter SMB username: " SMB_USER
read -sp "Enter SMB password: " SMB_PASS
echo

# Create required directories
mkdir -p "$HOME/.config/systemd/user" "$HOME/.local/bin" "$HOME/.unison" "$HOME/.smb"

# Save SMB credentials
cat > "$HOME/.smb/credentials" <<EOF
username=$SMB_USER
password=$SMB_PASS
EOF
chmod 600 "$HOME/.smb/credentials"

# Create autochmod script
tee "$HOME/.local/bin/autochmod.sh" <<EOF
#!/bin/bash
# Fix permissions on mount point
chown -R \$USER:\$USER "$MOUNT_POINT"
chmod -R 755 "$MOUNT_POINT"
EOF
chmod +x "$HOME/.local/bin/autochmod.sh"

# Create unison profile
tee "$HOME/.unison/smbsync.prf" <<EOF
root = $MOUNT_POINT
root = $MIRROR_PATH
auto = true
batch = true
EOF

# Detect unison binary path
UNISON_BIN=$(command -v unison)

# Create systemd user service files
tee "$HOME/.config/systemd/user/autochmod.service" <<EOF
[Unit]
Description=Auto chmod for SMB sync mount
After=default.target

[Service]
Type=oneshot
ExecStart=$HOME/.local/bin/autochmod.sh

[Install]
WantedBy=default.target
EOF

tee "$HOME/.config/systemd/user/unison-sync.service" <<EOF
[Unit]
Description=Unison SMB Sync Service
After=autochmod.service

[Service]
Type=oneshot
ExecStart=$UNISON_BIN smbsync

[Install]
WantedBy=default.target
EOF

tee "$HOME/.config/systemd/user/unison-sync.timer" <<EOF
[Unit]
Description=Run Unison SMB sync periodically

[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
Unit=unison-sync.service

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable units
systemctl --user daemon-reload
systemctl --user enable autochmod.service
systemctl --user enable unison-sync.service
systemctl --user enable unison-sync.timer

echo "Installation completed. You can start the services using:"
echo "  systemctl --user start autochmod.service"
echo "  systemctl --user start unison-sync.service"
echo "  systemctl --user start unison-sync.timer"
