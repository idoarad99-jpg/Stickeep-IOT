# Stickeep — Project Scope & Numbers

Snapshot taken 2026-07-21, from the actual git history.

## Timeline

- **First commit:** 2026-04-19
- **Latest commit:** 2026-07-21
- **Span:** ~3 months

## Commits & contributors

- **Total commits:** 151
- **Contributors:** QueenLuna666 (112), Marom (26), idoarad99-jpg (8), lunaabu-yunis (7)

## Code changed (cumulative, across all history)

- **~43,000 lines added, ~7,100 lines removed**, across 664 file changes

## Current codebase size

| Component | Lines | Files |
|---|---|---|
| Flutter app (`stickeep_app/lib/`) | 9,293 | 38 |
| ESP32 firmware — authored logic (`ESP32/*.ino`) | 1,315 | 10 |
| Cloud Functions (`stickeep_app/functions/index.js`) | 252 | 1 |

**Note:** `ESP32/` also contains ~3,580 lines across `.h`/`.c` files that
aren't authored logic — embedded JPEG image byte arrays
(`Main_screen135x240.h`, `Thank_you.h`, `Reserved.h`, `QR_image.h`) and
a vendored third-party QR-encoding library (`StickeepQrGen.c`, from
Richard Moore's "QRCode"). Those are excluded from the "authored logic"
figure above since they aren't code written for this project.
