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
      drawArrayJpeg(QR_image, sizeof(QR_image), 0, 0);
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

  // Battery
tft.fillRect(150, 10, 18, 12, TFT_WHITE);
tft.drawString(batteryText, 152, 14, 1);

  drawDateTimeStatus();
}

void drawMainScreenReservations() {
  tft.setTextColor(TFT_BLACK, TFT_WHITE);

  const int NUM_SLOTS = 8;

  String slotStart[NUM_SLOTS] = {
    "8:30",
    "9:30",
    "10:30",
    "11:30",
    "12:30",
    "13:30",
    "14:30",
    "15:30"
  };

  String slotEnd[NUM_SLOTS] = {
    "9:30",
    "10:30",
    "11:30",
    "12:30",
    "13:30",
    "14:30",
    "15:30",
    "16:30"
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