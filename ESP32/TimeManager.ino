void updateWifiStatusText()
{
  if (WiFi.status() == WL_CONNECTED)
  {
    wifiStatusText = "OK";
  }
  else
  {
    wifiStatusText = "Off";
  }

  if (wifiStatusText != previousWifiStatusText)
  {
    previousWifiStatusText = wifiStatusText;
    drawTopStatusBar();
  }
}

void initTime() {
  // Israel time
  configTime(2 * 3600, 3600, "pool.ntp.org", "time.nist.gov");

  struct tm timeinfo;

  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return;
  }

  Serial.println("Time initialized");
}

void updateDateTime()
{
  if (millis() - lastTimeUpdate < timeUpdateInterval)
    return;

  lastTimeUpdate = millis();

  struct tm timeinfo;

  if (!getLocalTime(&timeinfo))
    return;

  char dateBuffer[12];
  char timeBuffer[8];

  strftime(dateBuffer, sizeof(dateBuffer), "%d/%m/%y", &timeinfo);
  strftime(timeBuffer, sizeof(timeBuffer), "%H:%M", &timeinfo);

  String newDate = String(dateBuffer);
  String newTime = String(timeBuffer);

  if (newDate != currentDateText || newTime != currentTimeText)
  {
    currentDateText = newDate;
    currentTimeText = newTime;

    drawDateTimeStatus();
  }
}

int getCurrentMinutes()
{
  struct tm timeinfo;

  if (!getLocalTime(&timeinfo))
    return -1;

  return timeinfo.tm_hour * 60 + timeinfo.tm_min;
}

String getTodayDateString()
{
  struct tm timeinfo;

  if (!getLocalTime(&timeinfo))
    return "";

  char buffer[12];

  strftime(buffer, sizeof(buffer), "%d.%m.%Y", &timeinfo);

  return String(buffer);
}

int timeToMinutes(String timeStr)
{
  int colon = timeStr.indexOf(':');

  int hour =
      timeStr.substring(0, colon).toInt();

  int minute =
      timeStr.substring(colon + 1).toInt();

  return hour * 60 + minute;
}