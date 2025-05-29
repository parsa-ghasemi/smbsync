# SMB Sync with Unison and Autochmod

[🇮🇷 فارسی](README.fa.md)

A simple solution to synchronize a remote SMB folder to a local mirror on multiple Linux machines, with two-way synchronization and automatic permission fixing.

## 🔧 Features

- Automatically checks if the SMB mount is available
- Two-way synchronization via [Unison](https://www.cis.upenn.edu/~bcpierce/unison/)
- Automatic permission fix (`chmod 755`) on new files using `inotifywait`
- No need for `systemd` — works even on lightweight systems using cron and bash

## 🧩 Requirements

### Make sure the following packages are installed:

- `unison`
- `inotify-tools`
- `cifs-utils`
- `rsync`
- `cron`

## Install them on Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y cifs-utils rsync inotify-tools unison cron
```

## 🚀 Quick Setup
To install and configure the sync:

```bash
bash <(curl -s https://raw.githubusercontent.com/parsa-ghasemi/smbsync/main/install.sh)
```

## 🧹 Uninstalling
To remove the synchronization setup without deleting your files, run:

```bash
curl -s https://raw.githubusercontent.com/parsa-ghasemi/smbsync/main/uninstall.sh | bash
```

## 📁 Project Structure
```bash
.smbsync/
├── mount.sh           # Mounts SMB share
├── unison-sync.sh     # Handles two-way sync
├── autochmod.sh       # Watches folder for new files and fixes permissions
├── config.env         # Stores user-defined settings
├── unison.log         # Sync log file
└── autochmod.log      # Chmod log file
```
