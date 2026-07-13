# Setup notes for this firmware update

What changed and why is explained in the code comments, but here's what
you actually need to do before this compiles and runs correctly.

## 0. Hardware: ESP32 TTGO T-Display + PN532

This firmware now targets the **ESP32 TTGO T-Display** board (built-in
135x240 ST7789 screen) with a **PN532** NFC reader over **I2C** — this
supersedes both the older MFRC522/SPI wiring and the separate
`ESP32_OLED_PN532/` sketch, which are no longer the active target.

The TTGO's screen pins are soldered/fixed and can't be reused for
anything else: GPIO 4, 5, 16, 18, 19, 23 (see `TftSetupTTGO.h`). The
PN532 only needs two free GPIOs for I2C:

| PN532 pin | ESP32 TTGO GPIO |
|---|---|
| SDA | 21 |
| SCL | 22 |
| VCC | 3.3V |
| GND | GND |

## 1. Install the libraries

Via Arduino IDE Library Manager:
- **"PN532" by elechouse** — *not* in the standard Library Manager
  index; install by cloning `https://github.com/elechouse/PN532` and
  copying its `PN532/` and `PN532_I2C/` subfolders (flattened, not
  nested) into your Arduino `libraries/` folder. This is the same
  library Talia's original NFC code used, kept intentionally since it
  was already proven working. (The repo's `NDEF/` folder is *not*
  needed — that's only for writing/reading NDEF-formatted tag data,
  which this firmware doesn't do; we only read the raw card UID.)

The QR-generation code ("QRCode" by Richard Moore) is **vendored
directly in this folder** as `StickeepQrGen.h`/`StickeepQrGen.c` — you
don't need to install it separately. This was deliberate: the ESP32
Arduino core ships its own, completely different `qrcode.h` (for
Espressif's WiFi-provisioning feature) with the exact same filename,
and it was silently winning over the real library when both were
installed — this actually failed to compile until fixed. Renaming and
vendoring the real one avoids that collision for good, on any machine.

Everything else (WiFi provisioning) uses only libraries already built
into the ESP32 Arduino core (`WiFi`, `WebServer`, `DNSServer`,
`Preferences`, `esp_wpa2.h`) — nothing extra to install for that part.

**This has now actually been compiled successfully** (not just read) —
confirmed with a real ESP32 toolchain, zero errors. Flash usage is at
97% for this variant (TFT_eSPI + PN532/I2C together are heavier than
the previous MFRC522/SPI combination), so there's very little room left
before hitting the 1.3MB limit — worth flagging before adding anything
else non-trivial.

## 2. Fill in two config values (`IOT_Chair_20_6.ino`)

```cpp
const char* nfcConfirmFunctionUrl = "https://confirmnfcarrival-ehu6egweoa-uc.a.run.app";
const char* deviceApiKey = "REPLACE_WITH_DEVICE_API_KEY";
```

The function URL is already filled in and live. Ask the app team for
the current secret key value directly (not committed here on purpose,
since this file is version-controlled).

## 3. NFC reader pins are already set for this board

```cpp
const int NFC_SDA_PIN = 21;
const int NFC_SCL_PIN = 22;
```

These match the TTGO T-Display's free GPIOs and don't conflict with the
screen's fixed pins (see section 0 above) — no changes needed unless you
wire the PN532 differently.

## 4. WiFi setup no longer uses hardcoded credentials

On first boot (or if the device fails to connect with previously saved
credentials), it starts its own WiFi access point called
**"Stickeep-Setup"**. Connect to that from a phone/laptop, then open any
webpage (it should redirect automatically as a captive portal) — you'll
get a simple form to enter either:
- **Plain network** (home WiFi, phone hotspot): just SSID + password
- **Enterprise** (eduroam): SSID + identity + username + password

It saves what you enter and restarts, then connects normally. If you
ever need to re-provision (e.g. moving the device to a different
network), there's a `WIFI_RESET_PIN` constant currently set to `-1`
(disabled) — wire a button to a spare GPIO and set that constant to its
pin number, then hold it during boot to force back into setup mode.

## 5. Test plan, roughly in order

1. Flash and confirm it still boots and shows the main screen normally.
2. Confirm WiFi provisioning works (try both a plain network and, once
   you have credentials, eduroam).
3. Book a test reservation in the app for this seat, right now, and
   confirm the seat shows "reserved" and displays a real QR code (not
   the old placeholder) — scan it with the app to confirm arrival works.
4. Cancel a reservation in the app for a time slot that's still current,
   and confirm the seat correctly shows it as free (this was the P0 bug
   we found).
5. Once the Cloud Function is deployed and you have the real URL/key:
   test an NFC card tap, both a matching card (should confirm arrival)
   and a non-matching one (should show "Card not recognized" and let you
   retry).
6. Kill WiFi mid-session and confirm the device reconnects on its own
   instead of staying stuck.
