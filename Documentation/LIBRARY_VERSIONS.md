# Stickeep — Library & SDK Versions

Recorded 2026-07-14, from the actual toolchain used to build and verify
this project.

## Flutter app (`stickeep_app/`)

- **Flutter**: 3.22.1 (stable channel)
- **Dart**: 3.4.1
- **SDK constraint** (`pubspec.yaml`): `>=3.4.1 <4.0.0`

| Package | Version |
|---|---|
| firebase_core | ^2.27.0 |
| firebase_auth | ^4.20.0 |
| cloud_firestore | ^4.17.5 |
| firebase_database | ^10.4.9 |
| go_router | ^14.2.0 |
| mobile_scanner | ^5.2.3 |
| qr_flutter | ^4.1.0 |

## Cloud Functions (`stickeep_app/functions/`)

- **Node.js runtime**: 20 (2nd gen Cloud Functions)
- **firebase-admin**: ^12.6.0
- **firebase-functions**: ^5.1.1

## ESP32 firmware (`ESP32/`)

- **Board core**: `esp32:esp32` (Espressif Arduino core) **3.3.10**
- **Board**: ESP32 TTGO T-Display (built-in ST7789 135x240 TFT)
- **NFC reader**: PN532 (I2C)

| Library | Version | Source |
|---|---|---|
| TFT_eSPI | 2.5.43 | Arduino Library Manager |
| ArduinoJson | 7.4.3 | Arduino Library Manager |
| JPEGDecoder | 2.0.0 | Arduino Library Manager |
| PN532 (elechouse) | no tagged version — cloned from `github.com/elechouse/PN532` (main branch) | git clone, not in Library Manager |
| PN532_I2C (elechouse) | same as above | same repo |
| QRCode (Richard Moore's "QRCode") | 0.0.1 — vendored in-repo as `StickeepQrGen.h/.c` to avoid a filename collision with the ESP32 core's own `qrcode.h` | vendored |

Not used by the active firmware (kept installed locally from earlier
work, listed for completeness): Adafruit SSD1306 2.5.17, Adafruit GFX
Library 1.12.6, Adafruit BusIO 1.17.4, MFRC522 1.4.12, NDEF (unversioned).

Compilation verified with `arduino-cli compile --fqbn esp32:esp32:esp32`
— exit code 0, ~93% flash usage.
