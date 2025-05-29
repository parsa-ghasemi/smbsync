# SMB Sync with Unison and Autochmod

[🇮🇷 فارسی](README.fa.md)

A simple setup to sync a remote SMB folder to a local mirror on multiple machines, with two-way synchronization and automatic permission fixing.

## 🔧 Features

- Auto-check if SMB is mounted
- Two-way sync via [Unison](https://www.cis.upenn.edu/~bcpierce/unison/)
- Auto chmod on new files using `inotifywait`
- Lightweight systemd service for real-time chmod

## 🧩 Requirements

Make sure the following packages are installed:

- `unison`
- `inotify-tools`
- `cifs-utils`
- `systemd` (user mode)

Install them on Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y cifs-utils rsync inotify-tools unison
```

## Run this one-liner for quick Setup:
```bash
bash <(curl -s https://raw.githubusercontent.com/parsa-ghasemi/smbsync/main/install.sh)
```

## 🧹 Uninstalling

To remove the synchronization setup **without deleting your data**, run the uninstall script:

```bash
curl -s https://raw.githubusercontent.com/parsa-ghasemi/smbsync/main/uninstall.sh | bash
‍‍‍```
