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

There's also a status LED — a plain 4-leg **common-anode RGB LED** (not
an addressable WS2812/SK6812 — three separate PWM pins, not a data
line):

| LED pin | ESP32 TTGO GPIO |
|---|---|
| COM (longest leg) | 5V |
| R | 25 |
| G | 26 |
| B | 27 |

Color meaning: solid green = free, blinking blue = reservation
upcoming/awaiting arrival (within 15 min of start), blinking green (3s)
= arrival confirmed, solid blue = occupied, blinking red = NFC card
didn't match, solid red (highest priority, overrides everything) =
WiFi/communication fault. A wrong **QR** scan can't be shown here —
that mismatch happens entirely in the phone app and never reaches the
device. See `LedManager.ino`.

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
94% for this variant, so there's still very little room left before
hitting the 1.3MB limit — worth flagging before adding anything else
non-trivial.

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

## 4. WiFi — currently hardcoded, not the captive portal

A captive-portal provisioning flow exists in `WifiManager.ino`
(`startProvisioningPortal()` etc.) but **is not active right now** — it
wasn't showing up reliably during hardware testing, and the course
rules require using a phone hotspot for the live submission anyway
(Technion WiFi isn't allowed). Instead, `connectToWiFi()` connects
directly using two constants you need to fill in before flashing:

```cpp
const char* HARDCODED_WIFI_SSID = "REPLACE_WITH_SSID";
const char* HARDCODED_WIFI_PASSWORD = "REPLACE_WITH_PASSWORD";
```

Set these to the hotspot you'll actually use at submission time, and
test that exact combination in advance — don't rely on it working just
because it worked on a different WiFi network in the lab.

`WIFI_RESET_PIN` (currently `-1`, disabled) is unused while this is the
case — it only matters if the captive portal is re-enabled later.

## 5. Test plan, roughly in order

1. Flash and confirm it still boots and shows the main screen normally
   (LED should be solid green — free).
2. Confirm it connects using the hardcoded WiFi credentials (section 4).
3. Book a test reservation in the app for this seat, right now, and
   confirm the seat shows "reserved" and displays a real QR code (not
   the old placeholder) — LED should switch to blinking blue. Scan the
   QR with the app to confirm arrival works — LED should flash green
   (3s), then settle on solid blue (occupied).
4. Cancel a reservation in the app for a time slot that's still current,
   and confirm the seat correctly shows it as free (this was the P0 bug
   we found), LED back to solid green.
5. Test an NFC card tap: a matching card should confirm arrival (green
   flash, same as QR); a non-matching one should show "Card not
   recognized" on screen **and** blink the LED red for the same 1.5s
   window, then return to blinking blue.
6. Kill WiFi mid-session and confirm the device reconnects on its own
   instead of staying stuck — LED should go solid red while
   disconnected (overrides everything else), back to normal once
   reconnected.
