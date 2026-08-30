# 📟 KLICK // Offline Bluetooth & Wi-Fi P2P Communicator

<p align="center">
  <img src="assets/icons/KlickIcon.jpg" alt="KLICK Communicator" width="120" style="border-radius: 20px; box-shadow: 0 4px 20px rgba(0,0,0,0.4);" />
</p>

<p align="center">
  <b>Decentralized, off-grid peer-to-peer radio messenger built with Flutter.</b><br>
  No cellular data, no internet access, no SIM cards, and zero cloud servers required.
</p>

---

## ⚡ Key Capabilities

- 📻 **True Offline Mesh Communication**: Real-time peer-to-peer messaging via Bluetooth LE & Google Nearby Connections (`Strategy.P2P_CLUSTER`) and local Wi-Fi / LAN sockets.
- 📡 **Closed-App & Background Device Radar**: Detects nearby peers continuously—even when the app is in the background or the screen is locked.
- 🚨 **High-Priority Heads-Up Popup Notifications**: Instant banner popups for incoming messages, connection requests, and nearby device discoveries with screen-wake and vibration.
- ⚡ **Zero-Config Pairing & Callsign Identity**: One-tap interactive connection authorization with persistent friend memory for auto-reconnecting known peers.
- 📁 **High-Speed File & Image Sharing**: Stream photos, documents, and files directly over peer-to-peer TCP streams with real-time transfer progress.
- 📬 **Store-and-Forward Message Queue**: Queue messages while peers are temporarily out of radio range; automatically flushes and delivers once they come back in range.
- 🎮 **Tactile Bit-Mechanical Cyberdeck UI**: Retro LCD display with customizable color themes (Amber Gold, Cyber Emerald, Glitch Violet, Monochrome Dark), physical keyboard support, and optional hardware D-Pad controls.

---

## 📦 Releases & Installation

### 🤖 Android Release (APK & App Bundle)

#### 1. Pre-built Release APK
The compiled release APK is located at:
```
build/app/outputs/flutter-apk/app-release.apk
```

#### 2. Install on Device via ADB
```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

#### 3. Build from Source
- **Release APK**:
  ```bash
  flutter build apk --release
  ```
- **Google Play App Bundle (AAB)**:
  ```bash
  flutter build appbundle --release
  ```
  *(Output: `build/app/outputs/bundle/release/app-release.aab`)*

---

### 🍏 iOS Release (IPA / TestFlight / App Store)

#### 1. Prerequisites (macOS & Xcode)
- macOS with **Xcode 15+** installed
- **CocoaPods** (`sudo gem install cocoapods`)
- Apple Developer Account for device code-signing

#### 2. Build Release IPA
```bash
# 1. Install iOS Pod dependencies
cd ios && pod install && cd ..

# 2. Build Release IPA package
flutter build ipa --release
```
*(Output: `build/ios/archive/Runner.xcarchive` and `build/ios/ipa/*.ipa`)*

#### 3. Deploy to Device or TestFlight
- **Via Xcode Organizer**: Open `build/ios/archive/Runner.xcarchive` in Xcode and click **Distribute App** -> **TestFlight & App Store** or **Development / Ad-Hoc**.
- **Via CLI / Fastlane**:
  ```bash
  xcrun altool --upload-app -f build/ios/ipa/*.ipa -t ios -u "YOUR_APPLE_ID" -p "APP_SPECIFIC_PASSWORD"
  ```

---

### 🖥️ Windows Desktop Release
```bash
flutter build windows --release
```
*(Output: `build/windows/x64/runner/Release/`)*

---

## 🛠️ Permissions & System Requirements

### Android Permissions
- `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` (Android 12+ API 31+)
- `NEARBY_WIFI_DEVICES` (Android 13+ API 33+)
- `ACCESS_FINE_LOCATION` (Required for BLE beacon discovery on Android 11 and below)
- `POST_NOTIFICATIONS` (Android 13+ for heads-up alert popups)
- `FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_CONNECTED_DEVICE` (Keeps background radio active)
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (Prevents OEM battery killers from stopping discovery)

### iOS Permissions (`Info.plist`)
- `NSBluetoothAlwaysUsageDescription`
- `NSBluetoothPeripheralUsageDescription`
- `NSLocalNetworkUsageDescription`
- `NSBonjourServices` (`_klick-p2p._tcp`, `_klick-p2p._udp`)

---

## 🏗️ Architecture & Project Structure

```
lib/
├── controllers/
│   └── klick_controller.dart       # State machine, life cycle, discovery & message queue
├── models/
│   └── bluetooth_device.dart       # Device, Message, and Request domain models
├── screens/
│   ├── splash_screen.dart          # Retro hardware bootloader sequence
│   ├── onboarding_screen.dart      # Callsign configuration & radio introduction
│   ├── chats_list_screen.dart      # Contact list & offline conversation history
│   ├── conversation_screen.dart    # Two-way chat, file transmission, & LCD controls
│   └── discovery_screen.dart       # Radar scanner for nearby Bluetooth & Wi-Fi peers
├── services/
│   ├── background_service.dart     # Flutter bridge to Android Foreground Service
│   ├── bluetooth_service.dart      # Nearby Connections P2P_CLUSTER mesh driver
│   ├── local_p2p_service.dart      # UDP beacon discovery & high-speed TCP socket streaming
│   ├── notification_service.dart   # High-priority Heads-Up popup notification engine
│   └── storage_service.dart        # SharedPreferences persistence (Contacts, Messages, Queue)
├── theme/
│   └── bit_mechanical_theme.dart   # LCD palette shaders, typography, & tactile styling
└── widgets/
    ├── dpad_control.dart           # Directional physical navigation pad
    ├── hardware_shell.dart         # Cyberdeck body chassis & bezel frame
    ├── lcd_screen_container.dart   # Pixel grid shader container
    └── qwerty_keyboard.dart        # Physical QWERTY keyboard simulation
```

---

## 🧪 Testing & Verification

Run the comprehensive unit and integration test suite:

```bash
flutter analyze
flutter test
```

---

## 📄 License
Private & Proprietary — Developed for off-grid resilient peer-to-peer communications.

