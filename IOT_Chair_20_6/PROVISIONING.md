# Provisioning a new physical seat unit

Each seat display needs its own `SEAT_ID`, hardcoded at compile time
(`IOT_Chair_20_6.ino`), that must exactly match a seat created in the
admin app — they're two independent systems that only agree on a shared
string, so a mismatch here fails silently (the device just never finds
any reservations for a seat ID nobody created).

## Steps, in order

1. **Create the seat in the app first**, not the other way around. In the
   admin "Manage Seats" screen, add the seat under the right
   classroom (building + room), and note the exact sticker/seat ID
   entered — that's the string the firmware needs to match, character
   for character (it's case-sensitive).

2. **Set `SEAT_ID` in the firmware** before flashing:
   ```cpp
   const char* SEAT_ID = "SEAT_T2_1";  // <- change this per device
   ```
   This lives near the top of `IOT_Chair_20_6.ino`, alongside
   `firestoreProjectId`.

3. **Flash the device** with that build.

4. **Run through WiFi provisioning** (see `SETUP_NOTES.md`) — connect to
   the device's own "Stickeep-Setup" access point and enter the venue's
   network credentials.

5. **Verify end to end**: book a test reservation in the app for that
   exact seat, right now, and confirm the physical unit shows it as
   reserved and displays a scannable QR code. Don't skip this — it's the
   only way to catch a `SEAT_ID` typo before the unit goes out into a
   real room.

## Keep a simple tracking log

As more units get built, it's easy to lose track of which physical
device has which `SEAT_ID` flashed, especially if two people are
provisioning units at once. Keep a simple table somewhere shared (a
spreadsheet is fine) with at least:

| Physical unit (serial/label on the case) | SEAT_ID flashed | Classroom | Provisioned by | Date |
|---|---|---|---|---|
| e.g. unit #3 | SEAT_T2_1 | Taub 2 | Ido | 2026-07-10 |

Without this, a device that gets relabeled, swapped, or re-flashed for a
different room later has no way to trace what it's actually supposed to
be.

## If you need to re-provision an already-deployed unit

- **Change of WiFi network** (moved rooms/buildings): no reflash needed
  — wire a button to `WIFI_RESET_PIN` (currently disabled, set to `-1`
  in `IOT_Chair_20_6.ino`) and hold it at boot to re-enter the WiFi setup
  portal.
- **Change of `SEAT_ID`** (device physically moved to a different seat):
  this does need a reflash, since it's a compile-time constant. Update
  the tracking log at the same time.
