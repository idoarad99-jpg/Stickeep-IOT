void updateScreen() {
  tft.setRotation(1);
  tft.fillScreen(TFT_BLACK);

  switch (currentState) {
    case STATE_MAIN_SCREEN:
      Serial.println("State: MAIN_SCREEN");
      drawArrayJpeg(Main_screen135x240, sizeof(Main_screen135x240), 0, 0);
      drawTopStatusBar();
      drawMainScreenReservations();
      break;

    case STATE_QR_SCAN:
      Serial.println("State: QR_SCAN");
      drawQrScreen();
      drawTopStatusBar();
      break;

    case STATE_THANK_YOU:
      Serial.println("State: THANK_YOU");
      drawArrayJpeg(Thank_you, sizeof(Thank_you), 0, 0);
      drawTopStatusBar();
      break;

    case STATE_RESERVED:
      Serial.println("State: RESERVED");
      drawArrayJpeg(Reserved, sizeof(Reserved), 0, 0);
      drawTopStatusBar();
      drawReservedScreenData();
      break;
  }
}

void drawTopStatusBar() {
  tft.setTextColor(TFT_BLACK, TFT_WHITE);

  tft.fillRect(74, 10, 18, 6, TFT_WHITE);
  tft.drawString(wifiStatusText, 74, 14, 1);

  tft.fillRect(108, 10, 18, 12, TFT_WHITE);
  tft.drawString(seatSerialNumber, 108, 14, 1);

  drawDateTimeStatus();
}

// Was fixed to 8:30-16:30 in 1-hour blocks — any reservation outside
// that window (real bookings do run into the evening, e.g. 20:25-21:35
// in test data) showed up nowhere on this screen, making the seat look
// free while actually occupied. Widened to a full 8:00-24:00 day in
// 2-hour blocks instead. Still not truly "data-driven" from real
// classroom operating hours (that'd need a new Firestore schema field,
// out of scope before the submission deadline) but this closes the
// actual display-correctness gap with a minimal, low-risk change.
void drawMainScreenReservations() {
  tft.setTextColor(TFT_BLACK, TFT_WHITE);

  const int NUM_SLOTS = 8;

  String slotStart[NUM_SLOTS] = {
    "8:00",
    "10:00",
    "12:00",
    "14:00",
    "16:00",
    "18:00",
    "20:00",
    "22:00"
  };

  String slotEnd[NUM_SLOTS] = {
    "10:00",
    "12:00",
    "14:00",
    "16:00",
    "18:00",
    "20:00",
    "22:00",
    "24:00"
  };

  int slotX[NUM_SLOTS] = {
    70,
    70,
    70,
    70,
    180,
    180,
    180,
    180
  };

  int slotY[NUM_SLOTS] = {
    58,
    78,
    98,
    118,
    58,
    78,
    98,
    118
  };

  for (int i = 0; i < NUM_SLOTS; i++) {
    drawSlotStatus(slotStart[i], slotEnd[i], slotX[i], slotY[i]);
  }
}

void drawSlotStatus(String slotStart, String slotEnd, int x, int y) {
  bool reserved = false;

  int slotStartMin = timeToMinutes(slotStart);
  int slotEndMin = timeToMinutes(slotEnd);

  for (int i = 0; i < reservationCount; i++) {
    int resStartMin = timeToMinutes(resStart[i]);
    int resEndMin = timeToMinutes(resEnd[i]);

    // בדיקת חפיפה בין ההזמנה לבין חלון הזמן
    if (resStartMin < slotEndMin && resEndMin > slotStartMin) {
      reserved = true;
      break;
    }
  }

  tft.fillRect(x, y, 35, 10, TFT_WHITE);

  if (reserved) {
    tft.drawString("RES", x, y, 1);
  } else {
    tft.drawString("FREE", x, y, 1);
  }
}

void drawReservedScreenData() {
  tft.setTextColor(TFT_BLACK, TFT_WHITE);

  tft.fillRect(45, 63, 90, 12, TFT_WHITE);
  tft.drawString(activeStudentNumber, 45, 50, 1);

  tft.fillRect(75, 105, 45, 12, TFT_WHITE);
  tft.drawString(activeStartTime, 75, 105, 1);

  tft.fillRect(160, 105, 45, 12, TFT_WHITE);
  tft.drawString(activeEndTime, 160, 105, 1);
}

void drawDateTimeStatus()
{
  tft.setTextColor(TFT_BLACK, TFT_WHITE);

  // Date
  tft.fillRect(188, 3, 50, 10, TFT_WHITE);
  tft.drawString(currentDateText, 188, 4, 1);

  // Time
  tft.fillRect(190, 14, 40, 10, TFT_WHITE);
  tft.drawString(currentTimeText, 198, 15, 1);
}

// Renders a real QR code encoding the active reservation's qrToken, so a
// phone scanning it (via the app's existing camera scan) actually
// matches — replacing the old static placeholder image which could never
// match any real reservation. Requires the "QRCode" library by Richard
// Moore (Arduino Library Manager -> search "QRCode", ricmoo/QRCode).
//
// Screen is 240x135 in this rotation. Version 4 (33x33 modules) at 3px
// per module is 99x99px, comfortably fits with room for instruction text.
void drawQrScreen() {
  tft.fillScreen(TFT_WHITE);
  tft.setTextColor(TFT_BLACK, TFT_WHITE);

  if (activeQrToken.length() == 0) {
    tft.drawString("No active reservation", 40, 60, 1);
    return;
  }

  const int qrVersion = 4;
  QRCode qrcode;
  uint8_t qrcodeData[qrcode_getBufferSize(qrVersion)];
  qrcode_initText(&qrcode, qrcodeData, qrVersion, ECC_LOW, activeQrToken.c_str());

  const int scale = 3;
  const int qrPixelSize = qrcode.size * scale;
  const int offsetX = (240 - qrPixelSize) / 2;
  const int offsetY = 20;

  for (uint8_t y = 0; y < qrcode.size; y++) {
    for (uint8_t x = 0; x < qrcode.size; x++) {
      if (qrcode_getModule(&qrcode, x, y)) {
        tft.fillRect(offsetX + x * scale, offsetY + y * scale, scale, scale, TFT_BLACK);
      }
    }
  }

  tft.drawCentreString("Scan with the Stickeep app", 120, offsetY + qrPixelSize + 6, 1);
  tft.drawCentreString("or tap your student card", 120, offsetY + qrPixelSize + 18, 1);
}

// Briefly flashes a decline message when an NFC card doesn't match the
// active reservation, then returns to the QR scan screen so the student
// can try again (with their card or their phone).
void drawNfcDeclined() {
  tft.fillScreen(TFT_RED);
  tft.setTextColor(TFT_WHITE, TFT_RED);
  tft.drawCentreString("Card not recognized", 120, 55, 1);
  tft.drawCentreString("Try again or use the app", 120, 75, 1);
  delay(1500);
  drawQrScreen();
  drawTopStatusBar();
}

// Shows/clears a small warning icon in the status bar once fetches have
// been failing repeatedly (see registerSyncFailure/Success in
// FirebaseManager.ino), so a stale seat display doesn't go unnoticed
// indefinitely.
bool syncWarningActive = false;

void drawSyncWarning(bool show) {
  syncWarningActive = show;
  tft.fillRect(130, 10, 18, 12, show ? TFT_RED : TFT_WHITE);
  tft.setTextColor(show ? TFT_WHITE : TFT_BLACK, show ? TFT_RED : TFT_WHITE);
  tft.drawString(show ? "!" : "", 134, 14, 1);
}