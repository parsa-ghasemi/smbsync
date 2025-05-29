# همگام‌سازی SMB با Unison و Autochmod

[🇺🇸 English](README.md)

راهکاری ساده برای همگام‌سازی یک پوشه اشتراکی SMB با یک میرور محلی روی چند سیستم، با امکان همگام‌سازی دوطرفه و تنظیم خودکار سطح دسترسی فایل‌ها.

## 🔧 ویژگی‌ها

- بررسی خودکار Mount بودن پوشه اشتراکی SMB
- همگام‌سازی دوطرفه با استفاده از [Unison](https://www.cis.upenn.edu/~bcpierce/unison/)
- اعمال خودکار سطح دسترسی با `inotifywait`
- اجرای خودکار و سبک اسکریپت دسترسی با استفاده از سرویس systemd در پس‌زمینه

## 🧩 پیش‌نیازها

اطمینان حاصل کنید که بسته‌های زیر روی سیستم نصب هستند:

- `unison`
- `inotify-tools`
- `cifs-utils`
- `systemd` (در حالت user)

برای نصب روی Debian/Ubuntu از دستور زیر استفاده کنید:

```bash
sudo apt update
sudo apt install -y cifs-utils rsync inotify-tools unison
```

برای نصب سریع این کد را اجرا کنید:
```bash
bash <(curl -s https://raw.githubusercontent.com/parsa-ghasemi/smbsync/main/install.sh)

```

##🧹 حذف نصب


برای پاک کردن تنظیمات همگام‌سازی **بدون حذف داده‌های شما**، اسکریپت حذف را اجرا کنید:


```bash
sudo bash <(curl -s https://raw.githubusercontent.com/parsa-ghasemi/smbsync/main/uninstall.sh)
```
