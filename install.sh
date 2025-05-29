#!/bin/bash

# Ask for inputs with defaults
read -e -p "Enter mount point: " -i "$HOME/mnt/smbshare" MOUNT_POINT
read -e -p "Enter local mirror path: " -i "$HOME/mirror/smbshare" MIRROR_PATH
read -e -p "Enter remote address (e.g. //server/share): " -i "//192.168.1.100/shared" REMOTE_ADDR
read -e -p "Enter SMB username: " -i "guest" SMB_USER
read -sp "Enter SMB password: " SMB_PASS
echo

# Prepare directories
mkdir -p "$HOME/.config/systemd/user" "$HOME/.local/bin" "$HOME/.unison" "$HOME/.smb"

# Save SMB credentials
cat > "$HOME/.smb/credentials" <<EOF
username=$SMB_USER
password=$SMB_PASS
EOF
chmod 600 "$HOME/.smb/credentials"

# Create autochmod script to fix permissions
tee "$HOME/.local/bin/autochmod.sh" <<EOF
#!/bin/bash
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

# Detect Unison binary
UNISON_BIN=$(command -v unison)
if [ -z "$UNISON_BIN" ]; then
  echo "Error: Unison is not installed."
  exit 1
fi

# Create systemd services
tee "$HOME/.config/systemd/user/autochmod.service" <<EOF
[Unit]
Description=Auto chmod for SMB mount
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

# Reload systemd and enable services
systemctl --user daemon-reload
systemctl --user enable autochmod.service
systemctl --user enable unison-sync.service
systemctl --user enable unison-sync.timer

echo -e "\n✅ Setup complete!"
echo "You can start syncing with:"
echo "  systemctl --user start autochmod.service"
echo "  systemctl --user start unison-sync.service"
echo "  systemctl --user start unison-sync.timer"
