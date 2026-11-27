<!-- when: Phone work: installing apps, sending files or proof (Android CLI, KDE Connect) -->
# Android and phone

- To install an app on a connected device, use the Android CLI (`android install <apk>`), not `adb`, once the device is already connected through it. Use `adb` only as a fallback when the Android CLI does not work, and say so.
- To send the owner a light document, a screenshot, or proof of work, use KDE Connect: `kdeconnect-cli -l` lists devices, `kdeconnect-cli -d <device-id> --share <path>` sends a file. KDE Connect is also the fallback channel when the Android CLI or `adb` is not working. Send only light files, and ask first if the content is sensitive.
