# Stickeep — Connection Diagram (ESP32 TTGO T-Display + PN532)

## Overview

```
                    ┌─────────────────────────────┐
                    │   ESP32 TTGO T-Display       │
                    │   (built-in ST7789 TFT,      │
                    │    135 x 240, fixed pins)    │
                    │                               │
   PN532 (I2C) ─────┤ GPIO21 (SDA)                  │
                ┌───┤ GPIO22 (SCL)                  │
                │   │                               │
                │   │ GPIO4/5/16/18/19/23           │──── built-in TFT
                │   │  (reserved by the screen —    │     (no external
                │   │   do not reuse for anything)  │      wiring needed)
                │   │                               │
                │   │ GPIO15 ───────────────────────┼──── manual override
                │   │  (local-only test button)     │     button → GND
                │   │                               │
                │   │ USB ──────────────────────────┼──── power + flashing
                └───┤ 3.3V, GND                      │     (from a computer;
                    └─────────────────────────────┘     no battery used)
```

## Wiring table

| PN532 pin | ESP32 TTGO GPIO | Notes |
|---|---|---|
| SDA | GPIO 21 | Standard ESP32 I2C pin, free on this board |
| SCL | GPIO 22 | Standard ESP32 I2C pin, free on this board |
| VCC | 3.3V | **Not 5V** — keeps the I2C bus at the same logic level as the ESP32 (which is not 5V-tolerant); avoids risking damage through the SDA/SCL pull-ups |
| GND | GND | |

**PN532 mode switch**: must be set to **I2C mode** (not SPI/HSU) via the
module's onboard DIP switches/jumpers.

## Pins that are permanently unavailable

The TTGO T-Display's screen is soldered on and hardwired to fixed GPIOs
(see `ESP32/TftSetupTTGO.h`, vendored from TFT_eSPI's own
`Setup25_TTGO_T_Display.h`):

| Signal | GPIO |
|---|---|
| TFT_MOSI | 19 |
| TFT_SCLK | 18 |
| TFT_CS | 5 |
| TFT_DC | 16 |
| TFT_RST | 23 |
| TFT_BL (backlight) | 4 |

None of these can be reused for anything else on this board.

## Other pins in use

| Signal | GPIO | Purpose |
|---|---|---|
| `qrButtonPin` | 15 | Local-only manual override to simulate a QR scan during testing/demo — does **not** confirm arrival server-side, purely cosmetic for the demo. Free GPIO, no conflict with the screen or I2C pins. |
| `WIFI_RESET_PIN` | -1 (disabled) | Reserved for a future physical WiFi-reset button; not wired, not currently used (WiFi is set via hardcoded credentials, see `WifiManager.ino`). |
| `LED_R_PIN` / `LED_G_PIN` / `LED_B_PIN` | 25 / 26 / 27 | Status LED — see below. |

## Status LED (common-anode RGB, 3 pins)

A discrete 4-leg RGB LED (**not** an addressable WS2812/SK6812 — no
data protocol, just three PWM brightness channels), wired common-anode:

| LED pin | ESP32 GPIO |
|---|---|
| COM (longest leg) | 5V |
| R | GPIO 25 (through its inline current-limiting resistor) |
| G | GPIO 26 (through its inline current-limiting resistor) |
| B | GPIO 27 (through its inline current-limiting resistor) |

Because this is **common anode**, each color pin is active-LOW — a
lower PWM value is brighter. `LedManager.ino`'s `setLedColor()` inverts
this internally so the rest of the firmware can think in normal
(higher = brighter) terms.

Color meaning: solid blue = free, blinking blue = reservation
upcoming/awaiting arrival, green flash = arrival confirmed, red blink =
NFC card didn't match, solid red (highest priority) = WiFi/communication
fault. A wrong **QR** scan can't be shown here — that mismatch happens
entirely in the phone app and never reaches the device.

## Power

The device is powered over **USB from a computer** — there is no battery
in this project (not part of the course requirements for this build).

## Network

The device connects to WiFi using credentials hardcoded in
`WifiManager.ino` (`HARDCODED_WIFI_SSID` / `HARDCODED_WIFI_PASSWORD`).
**For the live submission, this must be set to a phone hotspot, not the
Technion WiFi network** — test this combination in advance.
