void updateStateMachine() {
  int nowMin = getCurrentMinutes();

  if (nowMin < 0)
    return;

  // THANK YOU screen for 1 minute
  if (currentState == STATE_THANK_YOU) {
    if (millis() - thankYouStartTime >= thankYouDuration) {
      currentState = STATE_RESERVED;
    }
    return;
  }

  // QR screen: accept either a phone scanning the displayed QR code (the
  // student's own app confirms arrival directly, no action needed here —
  // see reservation_card / scanner_screen on the app side) OR an NFC card
  // tap, checked here since the device itself makes that call. The
  // physical button remains as a local-only manual override for
  // testing/demo — it does NOT confirm arrival server-side.
  if (currentState == STATE_QR_SCAN) {
    String cardId;
    if (tryReadNfcCard(cardId)) {
      Serial.print("NFC card scanned: ");
      Serial.println(cardId);

      if (confirmNfcArrival(cardId)) {
        currentState = STATE_THANK_YOU;
        thankYouStartTime = millis();
      } else {
        // Card didn't match (or the request failed) — briefly show a
        // decline indicator, then keep waiting on this screen so the
        // student can try again (e.g. with their phone instead).
        drawNfcDeclined();
      }
      return;
    }

    if (digitalRead(qrButtonPin) == LOW) {
      Serial.println("QR scan simulated (manual override, local only)");

      currentState = STATE_THANK_YOU;
      thankYouStartTime = millis();

      delay(250);
    }
    return;
  }

  bool foundActiveReservation = false;

  for (int i = 0; i < reservationCount; i++) {
    int startMin = timeToMinutes(resStart[i]);
    int endMin = timeToMinutes(resEnd[i]);

    if (nowMin >= endMin)
      continue;

    if (nowMin >= startMin - 15 && nowMin < endMin) {
      foundActiveReservation = true;

      activeStartTime = resStart[i];
      activeEndTime = resEnd[i];
      activeStudentNumber = resStudentNumber[i];
      activeQrToken = resQrToken[i];

      Serial.print("Active student = ");
      Serial.println(activeStudentNumber);

      // If not already occupied/reserved, show QR
      if (currentState == STATE_MAIN_SCREEN) {
        currentState = STATE_QR_SCAN;
      }

      break;
    }
  }

  if (!foundActiveReservation) {
    currentState = STATE_MAIN_SCREEN;
    activeStartTime = "";
    activeEndTime = "";
    activeStudentNumber = "";
    activeQrToken = "";
  }
}