# همگام‌سازی SMB با Unison و Autochmod

[🇬🇧 English](README.md)

یک راهکار ساده برای همگام‌سازی یک پوشه‌ی اشتراکی SMB از راه دور با یک نسخه‌ی محلی در چندین ماشین لینوکسی، با پشتیبانی از همگام‌سازی دوطرفه و اصلاح خودکار سطح دسترسی فایل‌ها.

## 🔧 ویژگی‌ها

- بررسی خودکار در دسترس بودن اتصال SMB
- همگام‌سازی دوطرفه با استفاده از [Unison](https://www.cis.upenn.edu/~bcpierce/unison/)
- اصلاح خودکار سطح دسترسی فایل‌های جدید با استفاده از `inotifywait` (`chmod 755`)
- بدون نیاز به `systemd` — قابل اجرا حتی روی سیستم‌های سبک با استفاده از cron و bash

## 🧩 پیش‌نیازها

### مطمئن شوید بسته‌های زیر نصب شده باشند:

- `unison`
- `inotify-tools`
- `cifs-utils`
- `rsync`
- `cron`

## نصب در Debian/Ubuntu:

```bash
sudo apt update
sudo apt install -y cifs-utils rsync inotify-tools unison cron
````

## 🚀 نصب سریع

برای نصب و پیکربندی همگام‌سازی:

```bash
bash <(curl -s https://raw.githubusercontent.com/parsa-ghasemi/smbsync/main/install.sh)
```

## 🧹 حذف نرم‌افزار

برای حذف تنظیمات همگام‌سازی بدون حذف فایل‌های شما، این دستور را اجرا کنید:

```bash
curl -s https://raw.githubusercontent.com/parsa-ghasemi/smbsync/main/uninstall.sh | bash
```

## 📁 ساختار پروژه

```bash
.smbsync/
├── mount.sh           # اتصال پوشه‌ی SMB
├── unison-sync.sh     # اجرای همگام‌سازی دوطرفه
├── autochmod.sh       # پایش فایل‌های جدید و اصلاح سطح دسترسی آن‌ها
├── config.env         # تنظیمات تعریف‌شده توسط کاربر
├── unison.log         # لاگ همگام‌سازی
└── autochmod.log      # لاگ chmod
```
