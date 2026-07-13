# OLED + PN532 seat unit variant

This is a separate physical setup from `ESP32/` (which targets a TFT
display + MFRC522) — this one uses a small SSD1306 OLED and a PN532 NFC
reader, both over I2C. Adapted from Talia's original sketch; see the
comment block at the top of `ESP32_OLED_PN532.ino` for exactly what
changed and why (WiFi credentials removed + provisioning added, direct
Firestore writes replaced with the Cloud Function, the non-existent
`cardID` field removed, cancelled-reservation and active-time-window
bugs fixed).

## Before flashing

1. Fill in `deviceApiKey` (get the value from the app team — not
   committed here since this file is version-controlled).
2. Confirm which PN532 library is actually installed (`PN532_I2C.h` /
   `PN532.h`) — there are a few different Arduino PN532 libraries with
   similar but not identical APIs; this code assumes the common
   Adafruit-PN532-style API (`begin()`, `getFirmwareVersion()`,
   `SAMConfig()`, `readPassiveTargetID()`), matching what the original
   sketch already used.
3. Same as the TFT variant: on first boot (or holding a button wired to
   `WIFI_RESET_PIN`, currently disabled at `-1`), the device opens its
   own "Stickeep-Setup" WiFi access point with a setup page — connect to
   it and enter the venue's network details (works for both plain
   networks and eduroam).

## Not yet done

- **Not compiled or tested** — written without access to this specific
  hardware or an ESP32 toolchain in this environment. Braces/parens are
  balanced (a basic sanity check), but needs a real compile + flash +
  test pass before trusting it.
- No display of a QR code on this hardware at all — this variant is
  NFC-only. If QR-based confirmation is also wanted on this exact
  physical unit, that's not built here.
- Same open items as the TFT variant: no OTA updates, no real battery
  sensing, no rate limiting on the WiFi setup portal itself.

## Worth resolving with the team

There are now two independent firmware directions (`ESP32/` — TFT +
MFRC522, and this one — OLED + PN532). Worth a direct conversation about
which one is actually the intended final hardware, since they're not
compatible with each other and maintaining both indefinitely isn't
efficient.
