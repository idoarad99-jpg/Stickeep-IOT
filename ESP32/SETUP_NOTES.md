# Setup notes for this firmware update

What changed and why is explained in the code comments, but here's what
you actually need to do before this compiles and runs correctly.

## 1. Install one library (down from two)

Via Arduino IDE Library Manager:
- **"MFRC522" by GithubCommunity / miguelbalboa** — reads NFC cards for
  the tap-to-confirm arrival path.

The QR-generation code ("QRCode" by Richard Moore) is now **vendored
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
95% for this variant, so there isn't much room left before hitting the
1.3MB limit if more gets added — worth knowing if the next feature is
sizeable.

## 2. Fill in two config values (`IOT_Chair_20_6.ino`)

```cpp
const char* nfcConfirmFunctionUrl = "https://confirmnfcarrival-ehu6egweoa-uc.a.run.app";
const char* deviceApiKey = "REPLACE_WITH_DEVICE_API_KEY";
```

The function URL is already filled in and live. Ask the app team for
the current secret key value directly (not committed here on purpose,
since this file is version-controlled).

## 3. Confirm the NFC reader pins match your actual wiring

```cpp
const int NFC_SS_PIN = 5;
const int NFC_RST_PIN = 27;
```

These are placeholders too — pick real GPIOs based on how you wire the
MFRC522, and **double-check they don't conflict with the TFT display's
SPI pins** (configured separately in TFT_eSPI's `User_Setup.h`, not in
this sketch — I don't have visibility into that file). The MFRC522 can
share the same SPI bus as the display (different SS/CS pins), but if
anything else is already using GPIO 5 or 27, change these.

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
