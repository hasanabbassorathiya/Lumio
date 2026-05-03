# Lumio IPTV

<p align="center">
  <img src="assets/icons/app_icon.png" width="120" alt="Lumio IPTV Logo">
</p>

<p align="center">
  <strong>A Modern IPTV Player for Windows, Android, Android TV, and macOS</strong>
</p>

Lumio IPTV is a modern, high-performance IPTV player built with Flutter. Features a beautiful, elegant UI with dynamic gradient accents, optimized for seamless viewing across desktop, mobile, and TV platforms.

## 🚀 Getting Started

### 📋 Adding IPTV Playlists

To start watching channels, you need to add M3U/M3U8/TXT playlist sources:

#### 🌍 Free Public Playlists
For testing and demonstration purposes, you can use this free public playlist:
```
https://iptv-org.github.io/iptv/index.m3u
```

**How to add:**
1. Open Lumio IPTV
2. Click "Add Playlist" or "+" button
3. Select "From URL"
4. Paste the URL above
5. Click "Add" and wait for channels to load

#### 📁 Other Playlist Sources
- **Local Files**: Import `.m3u` or `.m3u8` files from your device
- **Custom URLs**: Add your own IPTV service URLs
- **QR Code**: Scan QR codes containing playlist URLs

> **Note**: The public playlist above contains channels from various countries and may have varying availability. For the best experience, use playlists from your IPTV service provider.

## 🚀 Download & Build

### Supported Platforms
- **Windows**: x64 Installer (.exe)
- **Android Mobile**: APK
- **Android TV**: APK
- **macOS**: App bundle

### Build Commands

```bash
# Clone the repository
git clone https://github.com/hasanabbassorathiya/lumio_iptv.git
cd lumio_iptv
flutter pub get

# Android Mobile APK
flutter build apk --release

# Android TV APK
flutter build apk --release --target-platform android-arm64

# macOS App
flutter build macos --release

# Windows
flutter build windows
```
