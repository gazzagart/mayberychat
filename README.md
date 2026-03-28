# LetsYak

LetsYak is an open source [Matrix](https://matrix.org) chat client built with [Flutter](https://flutter.dev). It is designed to be a clean, easy-to-use messenger with end-to-end encryption, cross-platform support, and a modern Material You interface.

# Features

- 📩 Send messages, images, and files
- 🎙️ Voice messages
- 📍 Location sharing
- 🔔 Push notifications
- 💬 Unlimited private and public group chats
- 📣 Public channels with thousands of participants
- 🛠️ Full Matrix group moderation tools
- 🔍 Discover and join public groups
- 🌙 Dark mode
- 🎨 Material You design
- 📟 Simple QR code sharing of Matrix IDs
- 😄 Custom emotes and stickers
- 🌌 Spaces
- 🔄 Compatible with Element, Nheko, NeoChat and all other Matrix clients
- 🔐 End-to-end encryption
- 🔒 Encrypted chat backup
- 😀 Emoji verification & cross signing

---

# How to Build

## 1. Prerequisites

### Flutter

Install Flutter by following the official guide for your platform: https://docs.flutter.dev/get-started/install

Verify your installation:
```bash
flutter doctor
```

All required items should show a green checkmark before proceeding. Fix any issues reported before continuing.

---

### Rust (required for all platforms)

Rust is required to compile the Vodozemac cryptography library.

**macOS / Linux:**
```bash
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
```

**Windows (PowerShell — run as Administrator):**

Download and run the official installer from https://rustup.rs, then restart your terminal.

Verify Rust is installed:
```bash
rustc --version
cargo --version
```

Then install the nightly toolchain and the `rust-src` component (required for Wasm compilation):

**macOS (Apple Silicon / arm64):**
```bash
rustup toolchain install nightly
rustup component add rust-src --toolchain nightly-aarch64-apple-darwin
```

**macOS (Intel / x86_64):**
```bash
rustup toolchain install nightly
rustup component add rust-src --toolchain nightly-x86_64-apple-darwin
```

**Linux (arm64):**
```bash
rustup toolchain install nightly
rustup component add rust-src --toolchain nightly-aarch64-unknown-linux-gnu
```

**Linux (x86_64):**
```bash
rustup toolchain install nightly
rustup component add rust-src --toolchain nightly-x86_64-unknown-linux-gnu
```

**Windows:**
```powershell
rustup toolchain install nightly
rustup component add rust-src --toolchain nightly-x86_64-pc-windows-msvc
```

---

### yq (required for the web prepare script)

**macOS:**
```bash
brew install yq
```

**Linux (Debian/Ubuntu):**
```bash
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq
```

**Windows:**
```powershell
choco install yq
```
> If you do not have Chocolatey, install it from https://chocolatey.org/install

---

## 2. Clone the Repository

```bash
git clone https://github.com/garethmaybery/mayberychat.git
cd mayberychat
```

---

## 3. Build for Your Platform

---

### Android

**Additional prerequisites:** Android Studio with the Android SDK installed. See https://docs.flutter.dev/get-started/install/macos/mobile-android

**Steps:**

```bash
flutter pub get
flutter build apk --release
```

The output APK will be at:
```
build/app/outputs/flutter-apk/app-release.apk
```

To build an App Bundle for the Play Store:
```bash
flutter build appbundle --release
```

> Optionally enable Firebase Cloud Messaging first:
> ```bash
> ./scripts/add-firebase-messaging.sh
> ```

---

### iOS / iPadOS

> **Requires macOS with Xcode installed.**

**Additional prerequisites:**
```bash
brew install cocoapods
```

**Steps:**

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ios --release
```

Or use the provided script which handles bundle ID and team rotation:

1. Set optional environment variables:
   ```bash
   export FLUFFYCHAT_NEW_GROUP="com.yourcompany.letsyak"   # Your app bundle ID
   export FLUFFYCHAT_NEW_TEAM="YOURTEAMID"                 # Your Apple Developer Team ID
   export FLUFFYCHAT_INSTALL_IPA=1                         # Optional: auto-install to device
   ```
2. Run the build script:
   ```bash
   ./scripts/build-ios.sh
   ```

---

### macOS (Desktop)

> **Requires macOS with Xcode installed.**

**Additional prerequisites:**
```bash
brew install cocoapods
flutter config --enable-macos-desktop
```

**Steps:**

```bash
flutter pub get
cd macos && pod install && cd ..
flutter build macos --release
```

Or use the provided script:

1. Set optional environment variables:
   ```bash
   export FLUFFYCHAT_NEW_GROUP="com.yourcompany.letsyak"
   export FLUFFYCHAT_NEW_TEAM="YOURTEAMID"
   ```
2. Run:
   ```bash
   ./scripts/build-macos.sh
   ```

The output app will be at:
```
build/macos/Build/Products/Release/LetsYak.app
```

---

### Web

The web build requires compiling the Vodozemac cryptography library to WebAssembly using Rust. The `prepare-web.sh` script handles this automatically.

**Additional prerequisites (macOS):**
```bash
brew install yq
```

**Additional prerequisites (Linux):**
```bash
sudo apt install curl wget jq build-essential
sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
sudo chmod +x /usr/bin/yq
```

**Additional prerequisites (Windows — PowerShell as Administrator):**
```powershell
choco install yq
```

**Steps:**

```bash
flutter pub get
# Install yq first if not already installed:
#   macOS:   brew install yq
#   Linux:   see prerequisites above
#   Windows: choco install yq  (then run the script via Git Bash or WSL)
./scripts/prepare-web.sh
flutter build web --dart-define=FLUTTER_WEB_CANVASKIT_URL=canvaskit/ --release --source-maps
```

**To run in debug mode (Chrome):**

> `prepare-web.sh` must be run at least once before `flutter run -d chrome` will work.

```bash
# Install yq first if not already installed:
#   macOS:   brew install yq
#   Linux:   see prerequisites above
#   Windows: choco install yq  (then run via Git Bash or WSL)
./scripts/prepare-web.sh
flutter run -d chrome
```

The output will be in `build/web/`. Serve it with any static file server, e.g.:
```bash
cd build/web && python3 -m http.server 8080
```

#### Docker (Web)

A `Dockerfile` is included. Build and run with:

```bash
docker build -t letsyak-web:latest .
docker run -p 8080:80 letsyak-web:latest
```

Then open http://localhost:8080 in your browser.

#### Configuration (Web)

Optionally serve a `config.json` at the same path as the app to customise it.  
See `config.sample.json` for all available options — all values are optional.  
Only include keys you actually want to change. For example, to set the default homeserver:

```json
{
  "defaultHomeserver": "matrix.example.com"
}
```

---

### Linux (Desktop)

**Additional prerequisites (Debian/Ubuntu):**
```bash
sudo apt install libjsoncpp1 libsecret-1-dev libsecret-1-0 librhash0 libwebkit2gtk-4.0-dev lld
flutter config --enable-linux-desktop
```

**Steps:**

```bash
flutter pub get
flutter build linux --release
```

The output binary will be at:
```
build/linux/x64/release/bundle/
```

---

### Windows (Desktop)

> **Requires Windows 10 or later with Visual Studio 2022 installed, including the "Desktop development with C++" workload.**  
> See https://docs.flutter.dev/get-started/install/windows/desktop

**Additional prerequisites (PowerShell — run as Administrator):**
```powershell
# Install Chocolatey if not already installed:
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install yq (required for prepare-web.sh)
choco install yq

# Install Git for Windows (provides Git Bash, required to run .sh scripts)
choco install git
```

Enable Windows desktop support:
```powershell
flutter config --enable-windows-desktop
```

**Steps:**

```powershell
flutter pub get
flutter build windows --release
```

Or use the provided script:
```powershell
.\scripts\build-windows.ps1
```

#### Running prepare-web.sh on Windows

The `prepare-web.sh` script requires a Unix shell. Run it via **Git Bash** (installed above):

1. Open **Git Bash** (search for it in the Start menu)
2. Navigate to the project directory:
   ```bash
   cd /c/path/to/mayberychat
   ```
3. Run the script:
   ```bash
   ./scripts/prepare-web.sh
   ```

Alternatively, if you have **WSL (Windows Subsystem for Linux)** installed, you can run it there:
```bash
wsl
cd /mnt/c/path/to/mayberychat
./scripts/prepare-web.sh
```

**To run in debug mode (Chrome) on Windows:**

> `prepare-web.sh` must be run at least once (via Git Bash or WSL) before `flutter run -d chrome` will work.

```powershell
flutter run -d chrome
```

The output will be at:
```
build\windows\x64\runner\Release\
```

---

## 4. Running in Debug Mode

For any platform, after running `flutter pub get`, start a debug session with:

```bash
flutter run
```

To target a specific device:
```bash
flutter devices          # list available devices
flutter run -d chrome    # web (see note below)
flutter run -d macos     # macOS desktop
flutter run -d windows   # Windows desktop
flutter run -d linux     # Linux desktop
```

> **Web note:** Before running `flutter run -d chrome` for the first time, you must run the web preparation steps:
> ```bash
> brew install yq          # macOS — skip if already installed
> ./scripts/prepare-web.sh
> ```
> On Windows, run `./scripts/prepare-web.sh` via Git Bash or WSL first (see the Windows section above).

---

# License

This project is licensed under the AGPL-3.0 License. See [LICENSE](LICENSE) for details.

---

# Acknowledgements

LetsYak is built on top of [FluffyChat](https://github.com/krille-chan/fluffychat) by [krille-chan](https://github.com/krille-chan).

- The Matrix Foundation for the [emoji translations](https://github.com/matrix-org/matrix-spec/blob/main/data-definitions/sas-emoji.json) used for emoji verification, licensed Apache 2.0
- <a href="https://github.com/madsrh/WoodenBeaver">WoodenBeaver</a> sound theme for the notification sound
