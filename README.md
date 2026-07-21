## Stickeep — Accessible Seat Reservation System

Built by the Stickeep team as part of ICST, Taub Faculty of Computer
Science, Technion.

## What this project does

Stickeep lets students reserve accessible seats in Technion classrooms
through a Flutter app, and confirm their physical arrival at the seat
in one of two ways: scanning a live QR code shown on a small screen
mounted at the seat, or tapping an NFC student card against a reader on
the same device — NFC exists specifically as an alternative for
students who may find it hard to aim a phone camera precisely at a
small on-screen code.

## Folder description

* **`ESP32/`** — firmware for the physical seat unit (ESP32 TTGO
  T-Display + PN532 NFC reader + status LED). See
  `ESP32/SETUP_NOTES.md` for build/flash instructions and
  `ESP32/PROVISIONING.md` for per-device setup.
* **`Documentation/`** — connection diagram, library/SDK versions,
  project scope numbers, and the printable edge-cases list. Start with
  `Documentation/CONNECTION_DIAGRAM.md`.
* **`Unit Tests/`** — early standalone hardware validation tests
  (display + WiFi) done before the full firmware in `ESP32/` existed.
* **`stickeep_app/`** — the Flutter app (student booking flow + admin
  panel), deployed at [stickeep.web.app](https://stickeep.web.app).
  Backed by Firebase (Firestore, Realtime Database, Auth, Hosting,
  Cloud Functions — see `stickeep_app/functions/`).

## ESP32 SDK version used in this project

Espressif `esp32:esp32` Arduino core, version **3.3.10**. Full details
(including every Arduino library and its version) are in
[`Documentation/LIBRARY_VERSIONS.md`](Documentation/LIBRARY_VERSIONS.md).

## Connection diagram

See [`Documentation/CONNECTION_DIAGRAM.md`](Documentation/CONNECTION_DIAGRAM.md)
for the full PN532 + status LED wiring and pin table.

## Project scope

Commit count, contributor breakdown, and lines-of-code numbers are in
[`Documentation/PROJECT_SCOPE.md`](Documentation/PROJECT_SCOPE.md).
