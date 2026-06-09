void drawMainScreenData()
{
  tft.setTextColor(TFT_BLACK, TFT_WHITE);

  // WiFi
  tft.drawString(wifiStatus, 74, 14, 1);

  // Serial number
  tft.drawString(serialNumber, 108, 14, 1);

  // Battery
  drawBattery(batteryPercent);

  drawDateTime();
}


//====================================================
// ציור אחוז סוללה
//====================================================
void drawBattery(int percent)
{
  // מחיקת הערך הישן

  tft.fillRect(155,14,35,10,TFT_WHITE);

  tft.setTextColor(TFT_BLACK, TFT_WHITE);

  tft.drawString(
      String(percent) + "%",152,14,1);
}


//====================================================
// עדכון סוללה מפוטנציומטר
//====================================================
void updateBatteryFromPot()
{
  // לא לעדכן אם לא במסך הראשי
  if(currentState != STATE_MAIN_SCREEN)
    return;

  // עדכון פעם בשנייה
  if(millis() - lastBatteryUpdate < batteryUpdateInterval)
    return;

  lastBatteryUpdate = millis();

  int potValue = analogRead(potPin);

  batteryPercent = map(
      potValue,
      0,
      4095,
      0,
      100);

  if(batteryPercent != lastBatteryPercent)
  {
    drawBattery(batteryPercent);

    Serial.print("ADC = ");
    Serial.print(potValue);

    Serial.print("   Battery = ");
    Serial.print(batteryPercent);
    Serial.println("%");

    lastBatteryPercent = batteryPercent;
  }
}

void drawDateTime() {
  tft.fillRect(187, 4, 50, 10, TFT_WHITE);
  tft.fillRect(195, 15, 40, 10, TFT_WHITE);

  tft.setTextColor(TFT_BLACK, TFT_WHITE);

  tft.drawString(currentDate, 187, 4, 1);
  tft.drawString(currentTime, 195, 15, 1);
}