#!/bin/bash

# Default values
DEF_MOUNT="$HOME/mnt/smbshare"
DEF_MIRROR="$HOME/mirror/smbshare"
DEF_REMOTE="//192.168.1.100/shared"
DEF_USER="guest"

# Ask for inputs with visible defaults
read -e -p "Enter mount point (default: $DEF_MOUNT): " -i "$DEF_MOUNT" MOUNT_POINT
read -e -p "Enter local mirror path (default: $DEF_MIRROR): " -i "$DEF_MIRROR" MIRROR_PATH
read -e -p "Enter remote address (default: $DEF_REMOTE): " -i "$DEF_REMOTE" REMOTE_ADDR
read -e -p "Enter SMB username (default: $DEF_USER): " -i "$DEF_USER" SMB_USER
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
Description=Run Unison Sync every 5 minutes

[Timer]
OnBootSec=30
OnUnitActiveSec=5min
Unit=unison-sync.service

[Install]
WantedBy=default.target
EOF

# Reload systemd and enable services
systemctl --user daemon-reload
systemctl --user enable autochmod.service
systemctl --user enable unison-sync.service
systemctl --user enable unison-sync.timer


echo "🔄 Starting and enabling systemd user services..."

systemctl --user daemon-reload
systemctl --user enable autochmod.service
systemctl --user enable unison-sync.service
systemctl --user enable unison-sync.timer

systemctl --user start autochmod.service
systemctl --user start unison-sync.service
systemctl --user start unison-sync.timer

echo "✅ All services started and enabled. Unison will sync every 5 minutes."
echo -e "\n✅ Setup complete!"

