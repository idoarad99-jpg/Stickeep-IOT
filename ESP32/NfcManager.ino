// ====================================================
// NFC Manager
// ====================================================
//
// Reads student ID cards via an MFRC522 reader (SPI) and confirms
// arrival through the confirmNfcArrival Cloud Function — the device has
// no Firebase Auth of its own, so it can't write to Firestore directly.
// This is the accessible alternative to the phone-camera QR scan: some
// students may not be able to reliably aim a phone camera at a small
// screen, so tapping a card is a second valid way to confirm arrival.
//
// Requires the "MFRC522" library by miguelbalboa (Arduino Library
// Manager -> search "MFRC522"). Wire the reader over SPI:
//   SDA/SS  -> NFC_SS_PIN
//   RST     -> NFC_RST_PIN
//   SCK/MOSI/MISO -> the ESP32's default VSPI pins (18/23/19), shared
//   with the TFT if it's also on SPI — check for bus conflicts with
//   TFT_eSPI's pin config before wiring.


MFRC522 mfrc522(NFC_SS_PIN, NFC_RST_PIN);

// Avoid re-reading + re-POSTing the same card over and over while it
// sits on the reader.
String lastCardId = "";
unsigned long lastCardReadTime = 0;
const unsigned long cardReadCooldown = 3000;

void setupNfc() {
  SPI.begin();
  mfrc522.PCD_Init();
  Serial.println("NFC reader initialized");
}

// Formats a scanned UID as colon-separated uppercase hex, matching the
// format the app stores student cards in (see signup_screen.dart's
// nfcCleaned normalization).
String formatCardId(MFRC522::Uid uid) {
  String result = "";
  for (byte i = 0; i < uid.size; i++) {
    if (i > 0) result += ":";
    if (uid.uidByte[i] < 0x10) result += "0";
    result += String(uid.uidByte[i], HEX);
  }
  result.toUpperCase();
  return result;
}

// Non-blocking check: returns true and fills cardIdOut if a new card was
// just read. Safe to call every loop() iteration.
bool tryReadNfcCard(String &cardIdOut) {
  if (!mfrc522.PICC_IsNewCardPresent() || !mfrc522.PICC_ReadCardSerial())
    return false;

  String cardId = formatCardId(mfrc522.uid);
  mfrc522.PICC_HaltA();

  unsigned long now = millis();
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
