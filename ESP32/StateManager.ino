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

  // QR screen waits for button press
  if (currentState == STATE_QR_SCAN) {
    if (digitalRead(qrButtonPin) == LOW) {
      Serial.println("QR scan simulated");

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
  }
}