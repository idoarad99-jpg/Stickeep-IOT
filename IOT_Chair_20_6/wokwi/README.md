# Running this firmware in the Wokwi simulator (visual, no physical hardware)

This lets you *see* the seat display's screen states (main/QR-scan/
thank-you/reserved) and test NFC card logic in a browser, without the
physical unit. It's a supplementary debugging aid, not a substitute for
testing on the real hardware — some things won't match exactly (see
caveats below).

## What's confirmed vs. what's my best guess

I checked directly in Wokwi's actual part picker (not just docs):
- **ST7789** (the real display driver, 135x240) — confirmed **not
  available** as a native Wokwi part. Zero search results.
- **MFRC522** (NFC reader) — confirmed available, exact pinout is from
  Wokwi's official docs.
- **ILI9341** (a different, common SPI TFT display) — confirmed to work
  with the TFT_eSPI library in Wokwi, via a real working example project.

Since there's no ST7789 simulation option, `diagram.json` in this folder
substitutes an **ILI9341 display as a stand-in**. It'll show the same
screen content (QR code, text, layout) since the drawing code doesn't
care which physical driver chip is underneath — but the resolution/
proportions won't be pixel-identical to the real 135x240 unit.

**One thing I could not verify**: the exact pin/signal names on Wokwi's
specific ILI9341 part (`SDI`/`SDO`/`D_C`/`LED` in the wiring below are my
best guess based on common ILI9341 breakout conventions, not confirmed
live in Wokwi's editor). If the simulation fails to wire up, open
`diagram.json` in Wokwi's visual diagram editor, click the display part,
and check the actual pin names it shows — adjust the `connections` array
to match if they differ from what's here.

## Pin assignments used (must match `IOT_Chair_20_6.ino`)

| Signal | GPIO | Note |
|---|---|---|
| Shared SPI bus | 18 (SCK), 19 (MISO), 23 (MOSI) | Both the display and MFRC522 share this bus |
| Display CS | 32 | Simulation-only choice — the real hardware's TFT pins are configured separately in TFT_eSPI's own `User_Setup.h`, not visible from this sketch |
| Display DC | 2 | |
| Display RST | 4 | |
| NFC (MFRC522) SS/SDA | 5 | Matches `NFC_SS_PIN` in the firmware |
| NFC (MFRC522) RST | 27 | Matches `NFC_RST_PIN` in the firmware |
| QR button | 15 | Matches `qrButtonPin` in the firmware |

## How to run it

1. Go to [wokwi.com/projects/new/esp32](https://wokwi.com/projects/new/esp32) — no account needed.
2. Delete the default `sketch.ino` content, and paste in each real firmware
   file as its own tab (use the tab bar's "+" to add files, matching the
   real filenames: `IOT_Chair_20_6.ino`, `FirebaseManager.ino`,
   `StateManager.ino`, `DisplayManager.ino`, `BatteryManager.ino`,
   `TimeManager.ino`, `Utils.ino`, `WifiManager.ino`, `NfcManager.ino`,
   plus the four `.h` image headers).
3. Open the `diagram.json` tab and replace its contents with the file in
   this folder.
4. Open **Library Manager** (tab at the top) and add: `TFT_eSPI`,
   `ArduinoJson`, `MFRC522`, `qrcode` (search "QRCode" by Richard Moore).
5. **TFT_eSPI needs to know it's driving an ILI9341 in this simulation**,
   which normally requires editing the library's own `User_Setup.h` —
   awkward to do inside Wokwi's browser editor. The simplest fix: add one
   more tab, name it `WokwiTftSetup.h`, containing:
   ```cpp
   #define USER_SETUP_LOADED 1
   #define ILI9341_DRIVER
   #define TFT_MISO 19
   #define TFT_MOSI 23
   #define TFT_SCLK 18
   #define TFT_CS   32
   #define TFT_DC    2
   #define TFT_RST   4
   #define LOAD_GLCD
   #define LOAD_FONT2
   #define SPI_FREQUENCY  40000000
   ```
   Then add `#include "WokwiTftSetup.h"` as the very first line of
   `IOT_Chair_20_6.ino`, **before** `#include <TFT_eSPI.h>`. Remove this
   one line before flashing the real hardware — it's simulation-only.
6. Click the green ▶ play button. The seat's screen states should render
   in the virtual display, and you can click the MFRC522 part to "tap" a
   virtual NFC card and test the confirm/decline flow.

## Known limitations

- Real eduroam WPA2-Enterprise auth and actual internet calls to the
  Cloud Function may not behave identically in simulation — good for
  checking display/logic, not a substitute for real-world network testing.
- Screen proportions/resolution will look slightly different than the
  real 135x240 unit (ILI9341 is natively 240x320, though `TFT_WIDTH`/
  `TFT_HEIGHT` can be constrained in `WokwiTftSetup.h` if you want a
  closer visual match).
- If the exact ILI9341 pin names in `diagram.json` don't match Wokwi's
  actual part, you'll get a wiring error in the simulator — check the
  part's real pin labels in the visual editor and adjust.
