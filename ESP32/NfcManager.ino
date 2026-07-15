// ====================================================
// NFC Manager
// ====================================================
//
// Reads student ID cards via a PN532 reader (I2C) and confirms arrival
// through the confirmNfcArrival Cloud Function — the device has no
// Firebase Auth of its own, so it can't write to Firestore directly.
// This is the accessible alternative to the phone-camera QR scan: some
// students may not be able to reliably aim a phone camera at a small
// screen, so tapping a card is a second valid way to confirm arrival.
//
// Requires the elechouse/Seeed-Studio "PN532" library (PN532_I2C.h +
// PN532.h — not Adafruit's "Adafruit PN532", which has a different API).
// Wire the reader over I2C:
//   SDA -> NFC_SDA_PIN (GPIO 21)
//   SCL -> NFC_SCL_PIN (GPIO 22)
//   VCC -> 3.3V, GND -> GND
// These are the ESP32's standard I2C pins and don't conflict with the
// TTGO T-Display's built-in screen (which uses GPIO 4/5/16/18/19/23).

PN532_I2C pn532_i2c(Wire);
PN532 nfc(pn532_i2c);
bool pn532Ready = false;

// PN532 reads block for up to the timeout passed to
// readPassiveTargetID() while waiting for a card — throttling how often
// it's actually attempted keeps the rest of loop() (WiFi maintenance,
// Firebase polling) responsive instead of stalling on every call.
unsigned long lastScanAttempt = 0;
const unsigned long scanAttemptInterval = 300;

// Avoid re-reading + re-POSTing the same card over and over while it
// sits on the reader.
String lastCardId = "";
unsigned long lastCardReadTime = 0;
const unsigned long cardReadCooldown = 3000;

void setupNfc() {
  Wire.begin(NFC_SDA_PIN, NFC_SCL_PIN);

  nfc.begin();
  uint32_t versiondata = nfc.getFirmwareVersion();

  if (!versiondata) {
    Serial.println("PN532 not detected (getFirmwareVersion returned 0) — check wiring/power");
    pn532Ready = false;
    return;
  }

  Serial.print("PN532 found, firmware version: 0x");
  Serial.println(versiondata, HEX);

  nfc.SAMConfig();
  pn532Ready = true;
  Serial.println("NFC reader initialized (PN532)");
}

// Formats a scanned UID as colon-separated uppercase hex, matching the
// format the app stores student cards in (see signup_screen.dart's
// nfcCleaned normalization).
String formatCardId(uint8_t *uid, uint8_t uidLength) {
  String result = "";
  for (uint8_t i = 0; i < uidLength; i++) {
    if (i > 0) result += ":";
    if (uid[i] < 0x10) result += "0";
    result += String(uid[i], HEX);
  }
  result.toUpperCase();
  return result;
}

// Non-blocking-ish check: returns true and fills cardIdOut if a new card
// was just read. Safe to call every loop() iteration — internally
// throttles how often it actually touches the reader.
bool tryReadNfcCard(String &cardIdOut) {
  if (!pn532Ready) return false;

  unsigned long now = millis();
  if (now - lastScanAttempt < scanAttemptInterval) return false;
  lastScanAttempt = now;

  uint8_t uid[7];
  uint8_t uidLength = 0;

  bool success = nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, 100);
  if (!success) return false;

  String cardId = formatCardId(uid, uidLength);

  if (cardId == lastCardId && now - lastCardReadTime < cardReadCooldown)
    return false;

  lastCardId = cardId;
  lastCardReadTime = now;
  cardIdOut = cardId;
  return true;
}

// POSTs to the confirmNfcArrival Cloud Function. Returns true only on a
// confirmed match (HTTP 200) — any other response (card mismatch, no
// active reservation, network error) returns false so the caller can
// show a decline indicator and let the student try again.
bool confirmNfcArrival(String cardId) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("confirmNfcArrival: no WiFi");
    return false;
  }

  HTTPClient http;
  http.begin(String(nfcConfirmFunctionUrl));
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-device-key", String(deviceApiKey));

  StaticJsonDocument<200> body;
  body["seatId"] = SEAT_ID;
  body["cardId"] = cardId;

  String payload;
  serializeJson(body, payload);

  int httpCode = http.POST(payload);
  String response = http.getString();
  http.end();

  Serial.print("confirmNfcArrival response (");
  Serial.print(httpCode);
  Serial.print("): ");
  Serial.println(response);

  return httpCode == 200;
}
