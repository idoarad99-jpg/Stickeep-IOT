void connectToWiFi() {
  Serial.print("Connecting to WiFi");

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }

  wifiStatus = "OK";

  Serial.println();
  Serial.println("WiFi connected");
}

void initTime() {
  // שעון ישראל
  configTime(2 * 3600, 3600, "pool.ntp.org", "time.nist.gov");

  struct tm timeinfo;

  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return;
  }

  Serial.println("Time initialized");
}

void updateDateTime() {
  if (currentState != STATE_MAIN_SCREEN)
    return;

  if (millis() - lastTimeUpdate < timeUpdateInterval)
    return;

  lastTimeUpdate = millis();

  struct tm timeinfo;

  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return;
  }

  char dateBuffer[12];
  char timeBuffer[8];

  strftime(dateBuffer, sizeof(dateBuffer), "%d/%m/%y", &timeinfo);
  strftime(timeBuffer, sizeof(timeBuffer), "%H:%M", &timeinfo);

  currentDate = String(dateBuffer);
  currentTime = String(timeBuffer);

  drawDateTime();
}