// =====================================================
// Stickeep seat unit — OLED (SSD1306) + PN532 (NFC) variant
// =====================================================
//
// Adapted from Talia's original sketch. What changed and why:
//
// 1. WiFi credentials were hardcoded in source (including a real personal
//    hotspot password) — removed. This version provisions WiFi the same
//    way the TFT variant does: on first boot it opens its own access
//    point ("Stickeep-Setup") with a simple web form, supports both plain
//    WPA2-PSK (hotspot/home) and WPA2-Enterprise (eduroam, which the
//    Technion actually uses and a plain WiFi.begin(ssid,password) can't
//    join), and auto-reconnects if the connection drops instead of
//    staying disconnected forever.
//
// 2. The original wrote nfc_status directly to Firestore with an
//    unauthenticated PATCH request. This fails under the security rules
//    already deployed (writes require a signed-in user, which this
//    device can never be) — confirmed this would get 403 Permission
//    Denied. Replaced with a call to the confirmNfcArrival Cloud
//    Function, which verifies the card match server-side (using
//    trusted, elevated access) and performs the write itself. The
//    device never touches Firestore for writes anymore, only reads.
//
// 3. The original expected a `cardID` field on each reservation
//    document — that field doesn't exist anywhere in the app's actual
//    data model (the registered card lives on the *seat* document as
//    `nfcSerialNumber`, set at booking time, not per-reservation). So
//    local card matching could never succeed. Removed entirely — the
//    scanned UID is now sent to the Cloud Function, which does the
//    matching against the real data itself.
//
// 4. `status` was fetched from each reservation but never checked, so a
//    cancelled booking still displayed as active — fixed to skip
//    `status == "cancelled"`.
//
// 5. There was no check that the current time actually falls within a
//    reservation's window — it always showed whichever reservation had
//    the earliest start time that day, even hours before it started or
//    after it ended. Fixed to pick the reservation whose window
//    (start - 15 min) to end actually contains the current time.
//
// Needs the same two libraries as the TFT variant for JSON/HTTP (already
// built in to ESP32 Arduino core: WiFi, HTTPClient, ArduinoJson), plus
// Adafruit_SSD1306 / Adafruit_GFX (Library Manager) and PN532 (Elechouse
// or Adafruit-PN532 — must expose PN532_I2C / PN532 classes as used
// below; confirm which one is actually installed before flashing).

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <Preferences.h>
#include "esp_wpa2.h"
#include "time.h"

#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#include <PN532_I2C.h>
#include <PN532.h>

// =====================================================
// USER CONFIG
// =====================================================

const char* firestoreProjectId = "stickeep";
const char* SEAT_ID = "SEAT_T2_1";

// Cloud Function — see stickeep_app/functions/index.js. Ask the app team
// for the current DEVICE_API_KEY value (not committed here on purpose,
// this file is version-controlled).
const char* nfcConfirmFunctionUrl = "https://confirmnfcarrival-ehu6egweoa-uc.a.run.app";
const char* deviceApiKey = "REPLACE_WITH_DEVICE_API_KEY";

// =====================================================
// I2C CONFIG
// =====================================================

#define SDA_PIN 21
#define SCL_PIN 22

#define OLED_ADDR 0x3C
#define PN532_ADDR 0x24

// =====================================================
// OLED CONFIG
// =====================================================

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET -1

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// =====================================================
// PN532 CONFIG
// =====================================================

PN532_I2C pn532_i2c(Wire);
PN532 nfc(pn532_i2c);

bool pn532Ready = false;

// =====================================================
// WIFI PROVISIONING (captive portal — see WifiManager.ino in ESP32/
// for the TFT variant; same approach, adapted to not need a display
// during setup mode since this screen is small — status is shown via
// Serial + a simple OLED message instead)
// =====================================================

Preferences wifiPrefs;
WebServer provisioningServer(80);
DNSServer dnsServer;
bool wifiProvisioningActive = false;

const char* provisioningApSsid = "Stickeep-Setup";
const byte DNS_PORT = 53;
const int NET_TYPE_NONE = 0;
const int NET_TYPE_PLAIN = 1;
const int NET_TYPE_ENTERPRISE = 2;

const int WIFI_RESET_PIN = -1; // set to a real GPIO once a reset button is wired; -1 disables this

unsigned long lastReconnectAttempt = 0;
const unsigned long reconnectRetryInterval = 15000;

void startProvisioningPortal();
void handleProvisioningRoot();
void handleProvisioningSave();
bool tryConnectWithStoredCredentials(unsigned long timeoutMs);
void connectToWiFi();
void maintainWifiConnection();

// =====================================================
// TIMERS
// =====================================================

const unsigned long FIREBASE_UPDATE_INTERVAL_MS = 15000;
const unsigned long NFC_SCAN_INTERVAL_MS = 400;
const unsigned long RESULT_SCREEN_DURATION_MS = 3000;

unsigned long lastFirebaseUpdate = 0;
unsigned long lastNfcScanAttempt = 0;
unsigned long resultScreenStart = 0;

// =====================================================
// RESERVATION DATA
// =====================================================

struct Reservation {
  String documentId;
  String startTime;
  String endTime;
  String status;
  String studentNumber;
  String nfcStatus;
};

Reservation activeReservation;
bool hasReservationToday = false;

String lastScannedUID = "";
String dbErrorText = "";

// =====================================================
// STATE MACHINE
// =====================================================

enum AppState {
  STATE_BOOT,
  STATE_WIFI_CONNECTING,
  STATE_WIFI_PROVISIONING,
  STATE_PN532_LOADING,
  STATE_DB_LOADING,
  STATE_NO_RESERVATION,
  STATE_READY_TO_SCAN,
  STATE_NFC_UPDATING,
  STATE_ARRIVAL_APPROVED,
  STATE_WRONG,
  STATE_NFC_UPDATE_ERROR,
  STATE_DB_ERROR,
  STATE_PN532_ERROR
};

AppState currentState = STATE_BOOT;

// =====================================================
// FUNCTION DECLARATIONS
// =====================================================

void initI2C();
void initOLED();
void initPN532();

bool initTime();

bool fetchActiveTodayReservation();
String firestoreString(JsonObject fields, const char* fieldName);
String extractDocumentId(const String &documentName);
bool isNfcApproved(const String &statusText);

String getTodayDateString();
int timeToMinutes(String timeStr);
int getCurrentMinutes();

bool scanCardOnce(String &scannedUID);
String uidToString(uint8_t *uid, uint8_t uidLength);

enum NfcConfirmResult { NFC_CONFIRM_APPROVED, NFC_CONFIRM_DECLINED, NFC_CONFIRM_ERROR };
NfcConfirmResult confirmNfcArrival(const String &scannedUID);

void setState(AppState newState);
void updateStateMachine();

void drawScreen();
void drawBoot();
void drawWiFiConnecting();
void drawWiFiProvisioning();
void drawPn532Loading();
void drawDbLoading();
void drawNoReservation();
void drawReadyToScan();
void drawNfcUpdating();
void drawArrivalApproved();
void drawWrong();
void drawNfcUpdateError();
void drawDbError();
void drawPn532Error();

bool i2cDeviceExists(uint8_t address);
void printI2CCheck();

// =====================================================
// SETUP
// =====================================================

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println();
  Serial.println("===== OLED + PN532 + FIRESTORE =====");

  initI2C();
  initOLED();

  drawBoot();
  delay(800);

  printI2CCheck();

  if (WIFI_RESET_PIN >= 0) {
    pinMode(WIFI_RESET_PIN, INPUT_PULLUP);
  }
  wifiPrefs.begin("wifi", false);

  setState(STATE_WIFI_CONNECTING);
  connectToWiFi();

  if (wifiProvisioningActive) {
    // Provisioning portal is running; setup() returns and loop() drives
    // it until the installer saves credentials and the device restarts.
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    dbErrorText = "WiFi failed";
    setState(STATE_DB_ERROR);
    return;
  }

  if (!initTime()) {
    dbErrorText = "Time failed";
    setState(STATE_DB_ERROR);
    return;
  }

  setState(STATE_PN532_LOADING);
  initPN532();

  if (!pn532Ready) {
    setState(STATE_PN532_ERROR);
    return;
  }

  setState(STATE_DB_LOADING);

  if (fetchActiveTodayReservation()) {
    if (isNfcApproved(activeReservation.nfcStatus)) {
      setState(STATE_ARRIVAL_APPROVED);
    } else {
      setState(STATE_READY_TO_SCAN);
    }
  } else {
    if (dbErrorText.length() > 0) {
      setState(STATE_DB_ERROR);
    } else {
      setState(STATE_NO_RESERVATION);
    }
  }
}

// =====================================================
// LOOP
// =====================================================

void loop() {
  maintainWifiConnection();
  if (wifiProvisioningActive) return;

  updateStateMachine();
  delay(20);
}

// =====================================================
// INIT
// =====================================================

void initI2C() {
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(100000);
  Serial.println("I2C initialized");
}

void initOLED() {
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    Serial.println("OLED init failed");
    while (true) { delay(1000); }
  }
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.display();
  Serial.println("OLED initialized");
}

void initPN532() {
  Serial.println("===== PN532 INIT =====");
  nfc.begin();
  uint32_t versiondata = nfc.getFirmwareVersion();

  if (!versiondata) {
    Serial.println("PN532 firmware not detected");
    pn532Ready = false;
    return;
  }

  Serial.print("Chip: PN5"); Serial.println((versiondata >> 24) & 0xFF, HEX);
  nfc.SAMConfig();
  pn532Ready = true;
  Serial.println("PN532 ready");
}

// =====================================================
// WIFI PROVISIONING + CONNECTION
// =====================================================

void connectToWiFi() {
  WiFi.mode(WIFI_STA);

  int netType = wifiPrefs.getInt("netType", NET_TYPE_NONE);
  bool holdingResetButton =
      (WIFI_RESET_PIN >= 0) && (digitalRead(WIFI_RESET_PIN) == LOW);

  if (netType == NET_TYPE_NONE || holdingResetButton) {
    Serial.println("Entering WiFi provisioning");
    setState(STATE_WIFI_PROVISIONING);
    startProvisioningPortal();
    return;
  }

  Serial.println("Connecting to stored WiFi network...");
  if (!tryConnectWithStoredCredentials(20000)) {
    Serial.println("Failed to connect with stored credentials — entering provisioning");
    setState(STATE_WIFI_PROVISIONING);
    startProvisioningPortal();
  }
}

bool tryConnectWithStoredCredentials(unsigned long timeoutMs) {
  int netType = wifiPrefs.getInt("netType", NET_TYPE_NONE);
  if (netType == NET_TYPE_NONE) return false;

  String ssid = wifiPrefs.getString("ssid", "");

  if (netType == NET_TYPE_PLAIN) {
    String password = wifiPrefs.getString("password", "");
    WiFi.begin(ssid.c_str(), password.c_str());
  } else {
    // WPA2-Enterprise (eduroam)
    String identity = wifiPrefs.getString("identity", "");
    String username = wifiPrefs.getString("username", "");
    String password = wifiPrefs.getString("password", "");

    esp_wifi_sta_wpa2_ent_set_identity((uint8_t *)identity.c_str(), identity.length());
    esp_wifi_sta_wpa2_ent_set_username((uint8_t *)username.c_str(), username.length());
    esp_wifi_sta_wpa2_ent_set_password((uint8_t *)password.c_str(), password.length());
    esp_wifi_sta_wpa2_ent_enable();
    WiFi.begin(ssid.c_str());
  }

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
    delay(300);
    Serial.print(".");
  }
  Serial.println();

  return WiFi.status() == WL_CONNECTED;
}

void maintainWifiConnection() {
  if (wifiProvisioningActive) {
    dnsServer.processNextRequest();
    provisioningServer.handleClient();
    return;
  }

  if (WiFi.status() == WL_CONNECTED) return;

  unsigned long now = millis();
  if (now - lastReconnectAttempt < reconnectRetryInterval) return;
  lastReconnectAttempt = now;

  Serial.println("WiFi disconnected — attempting reconnect...");
  tryConnectWithStoredCredentials(8000);
}

void startProvisioningPortal() {
  wifiProvisioningActive = true;

  WiFi.mode(WIFI_AP);
  WiFi.softAP(provisioningApSsid);
  dnsServer.start(DNS_PORT, "*", WiFi.softAPIP());

  provisioningServer.on("/", handleProvisioningRoot);
  provisioningServer.on("/save", HTTP_POST, handleProvisioningSave);
  provisioningServer.onNotFound(handleProvisioningRoot);
  provisioningServer.begin();

  Serial.print("Provisioning AP started: ");
  Serial.println(provisioningApSsid);
  Serial.print("Connect to it, then open: http://");
  Serial.println(WiFi.softAPIP());
}

void handleProvisioningRoot() {
  String html =
      "<html><body style='font-family:sans-serif;padding:16px'>"
      "<h2>Stickeep seat WiFi setup</h2>"
      "<form action='/save' method='POST'>"
      "<label>Network type:</label><br>"
      "<select name='netType'>"
      "<option value='1'>Plain (home WiFi / hotspot)</option>"
      "<option value='2'>Enterprise (eduroam)</option>"
      "</select><br><br>"
      "<label>Network name (SSID):</label><br>"
      "<input name='ssid' type='text'><br><br>"
      "<label>Identity (enterprise only, often same as username):</label><br>"
      "<input name='identity' type='text'><br><br>"
      "<label>Username (enterprise only):</label><br>"
      "<input name='username' type='text'><br><br>"
      "<label>Password:</label><br>"
      "<input name='password' type='password'><br><br>"
      "<button type='submit'>Save and connect</button>"
      "</form></body></html>";
  provisioningServer.send(200, "text/html", html);
}

void handleProvisioningSave() {
  int netType = provisioningServer.arg("netType").toInt();
  String ssid = provisioningServer.arg("ssid");
  String identity = provisioningServer.arg("identity");
  String username = provisioningServer.arg("username");
  String password = provisioningServer.arg("password");

  wifiPrefs.putInt("netType", netType);
  wifiPrefs.putString("ssid", ssid);
  wifiPrefs.putString("identity", identity);
  wifiPrefs.putString("username", username);
  wifiPrefs.putString("password", password);

  provisioningServer.send(
      200, "text/html",
      "<html><body style='font-family:sans-serif;padding:16px'>"
      "<h3>Saved. Restarting...</h3></body></html>");

  delay(1000);
  ESP.restart();
}

// =====================================================
// TIME
// =====================================================

bool initTime() {
  Serial.println("Initializing time from NTP...");
  configTime(2 * 3600, 3600, "time.google.com", "pool.ntp.org", "time.nist.gov");

  struct tm timeinfo;
  for (int i = 0; i < 40; i++) {
    if (getLocalTime(&timeinfo, 1000)) {
      Serial.println("Time initialized");
      return true;
    }
    Serial.print(".");
  }
  Serial.println();
  Serial.println("Failed to obtain time");
  return false;
}

String getTodayDateString() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "";
  char buffer[12];
  strftime(buffer, sizeof(buffer), "%d.%m.%Y", &timeinfo);
  return String(buffer);
}

int timeToMinutes(String timeStr) {
  int colon = timeStr.indexOf(':');
  if (colon < 0) return 99999;
  int hour = timeStr.substring(0, colon).toInt();
  int minute = timeStr.substring(colon + 1).toInt();
  return hour * 60 + minute;
}

int getCurrentMinutes() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return -1;
  return timeinfo.tm_hour * 60 + timeinfo.tm_min;
}

// =====================================================
// FIRESTORE (read-only — all writes go through the Cloud Function)
// =====================================================

String firestoreString(JsonObject fields, const char* fieldName) {
  JsonVariant v = fields[fieldName]["stringValue"];
  if (v.isNull()) return "";
  return v.as<String>();
}

String extractDocumentId(const String &documentName) {
  int lastSlash = documentName.lastIndexOf('/');
  if (lastSlash < 0 || lastSlash >= documentName.length() - 1) return "";
  return documentName.substring(lastSlash + 1);
}

bool isNfcApproved(const String &statusText) {
  String normalized = statusText;
  normalized.trim();
  normalized.toLowerCase();
  return normalized == "approved";
}

// Picks the reservation that's actually active RIGHT NOW (within 15
// minutes before its start through its end), skipping cancelled ones —
// the original picked whichever reservation had the earliest start time
// of the day, with no time-window or status check at all.
bool fetchActiveTodayReservation() {
  dbErrorText = "";
  lastFirebaseUpdate = millis();

  if (WiFi.status() != WL_CONNECTED) {
    dbErrorText = "WiFi off";
    return false;
  }

  String today = getTodayDateString();
  int nowMin = getCurrentMinutes();

  if (today.length() == 0 || nowMin < 0) {
    dbErrorText = "No date";
    return false;
  }

  String url =
    "https://firestore.googleapis.com/v1/projects/" +
    String(firestoreProjectId) +
    "/databases/(default)/documents/seats/" +
    String(SEAT_ID) +
    "/reservations";

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;

  if (!http.begin(client, url)) {
    dbErrorText = "HTTP begin fail";
    return false;
  }

  int httpCode = http.GET();

  if (httpCode != 200) {
    dbErrorText = "HTTP " + String(httpCode);
    http.end();
    return false;
  }

  String payload = http.getString();
  http.end();

  DynamicJsonDocument doc(50000);
  DeserializationError error = deserializeJson(doc, payload);

  if (error) {
    dbErrorText = "JSON error";
    return false;
  }

  JsonArray documents = doc["documents"].as<JsonArray>();
  bool found = false;
  Reservation best;

  for (JsonObject reservationDoc : documents) {
    JsonObject fields = reservationDoc["fields"];

    String date = firestoreString(fields, "date");
    if (date != today) continue;

    String status = firestoreString(fields, "status");
    if (status == "cancelled") continue;

    String startTime = firestoreString(fields, "startTime");
    String endTime = firestoreString(fields, "endTime");
    int startMin = timeToMinutes(startTime);
    int endMin = timeToMinutes(endTime);

    // Only a reservation whose window actually contains "now" counts as
    // active — same 15-minute-early grace period as the TFT variant.
    if (nowMin < startMin - 15 || nowMin >= endMin) continue;

    found = true;
    String documentName = reservationDoc["name"].as<String>();
    best.documentId = extractDocumentId(documentName);
    best.startTime = startTime;
    best.endTime = endTime;
    best.status = status;
    best.studentNumber = firestoreString(fields, "studentNumber");
    best.nfcStatus = firestoreString(fields, "nfc_status");
    best.nfcStatus.trim();
    break; // seats shouldn't have overlapping active reservations
  }

  hasReservationToday = found;

  if (!found) {
    activeReservation = Reservation();
    return false;
  }

  activeReservation = best;

  Serial.println("----- ACTIVE RESERVATION -----");
  Serial.print("Student: "); Serial.println(activeReservation.studentNumber);
  Serial.print("Start: "); Serial.println(activeReservation.startTime);
  Serial.print("End: "); Serial.println(activeReservation.endTime);
  Serial.print("nfc_status: "); Serial.println(activeReservation.nfcStatus);

  return true;
}

// Sends the scanned card to the Cloud Function, which matches it against
// the seat's actual registered card server-side and performs the write
// itself — the device never writes to Firestore directly.
NfcConfirmResult confirmNfcArrival(const String &scannedUID) {
  if (WiFi.status() != WL_CONNECTED) {
    dbErrorText = "WiFi off";
    return NFC_CONFIRM_ERROR;
  }

  HTTPClient http;
  http.begin(String(nfcConfirmFunctionUrl));
  http.addHeader("Content-Type", "application/json");
  http.addHeader("x-device-key", String(deviceApiKey));

  StaticJsonDocument<200> body;
  body["seatId"] = SEAT_ID;
  body["cardId"] = scannedUID;

  String payload;
  serializeJson(body, payload);

  int httpCode = http.POST(payload);
  String response = http.getString();
  http.end();

  Serial.print("confirmNfcArrival response ("); Serial.print(httpCode); Serial.print("): ");
  Serial.println(response);

  if (httpCode == 200) {
    activeReservation.nfcStatus = "approved";
    lastFirebaseUpdate = millis();
    return NFC_CONFIRM_APPROVED;
  }
  if (httpCode == 403 || httpCode == 409) {
    return NFC_CONFIRM_DECLINED;
  }

  dbErrorText = "HTTP " + String(httpCode);
  return NFC_CONFIRM_ERROR;
}

// =====================================================
// STATE MACHINE
// =====================================================

void setState(AppState newState) {
  if (currentState == newState) return;
  currentState = newState;
  drawScreen();
}

void updateStateMachine() {
  if (currentState == STATE_WRONG || currentState == STATE_NFC_UPDATE_ERROR) {
    if (millis() - resultScreenStart >= RESULT_SCREEN_DURATION_MS) {
      setState(STATE_READY_TO_SCAN);
    }
    return;
  }

  if (currentState == STATE_ARRIVAL_APPROVED) {
    return;
  }

  if (currentState == STATE_READY_TO_SCAN) {
    if (millis() - lastFirebaseUpdate >= FIREBASE_UPDATE_INTERVAL_MS) {
      bool ok = fetchActiveTodayReservation();

      if (!ok) {
        setState(dbErrorText.length() > 0 ? STATE_DB_ERROR : STATE_NO_RESERVATION);
        return;
      }
      if (isNfcApproved(activeReservation.nfcStatus)) {
        setState(STATE_ARRIVAL_APPROVED);
        return;
      }
      drawReadyToScan();
    }

    if (millis() - lastNfcScanAttempt < NFC_SCAN_INTERVAL_MS) return;
    lastNfcScanAttempt = millis();

    String scannedUID = "";
    if (scanCardOnce(scannedUID)) {
      lastScannedUID = scannedUID;
      lastScannedUID.trim();

      setState(STATE_NFC_UPDATING);
      NfcConfirmResult result = confirmNfcArrival(lastScannedUID);

      if (result == NFC_CONFIRM_APPROVED) {
        setState(STATE_ARRIVAL_APPROVED);
      } else if (result == NFC_CONFIRM_DECLINED) {
        resultScreenStart = millis();
        setState(STATE_WRONG);
      } else {
        resultScreenStart = millis();
        setState(STATE_NFC_UPDATE_ERROR);
      }
    }
    return;
  }

  if (currentState == STATE_DB_ERROR || currentState == STATE_NO_RESERVATION) {
    if (millis() - lastFirebaseUpdate >= FIREBASE_UPDATE_INTERVAL_MS) {
      setState(STATE_DB_LOADING);
      if (fetchActiveTodayReservation()) {
        setState(isNfcApproved(activeReservation.nfcStatus) ? STATE_ARRIVAL_APPROVED : STATE_READY_TO_SCAN);
      } else {
        setState(dbErrorText.length() > 0 ? STATE_DB_ERROR : STATE_NO_RESERVATION);
      }
    }
    return;
  }
}

// =====================================================
// PN532 CARD SCAN
// =====================================================

bool scanCardOnce(String &scannedUID) {
  if (!pn532Ready) return false;

  uint8_t uid[7];
  uint8_t uidLength = 0;

  bool success = nfc.readPassiveTargetID(PN532_MIFARE_ISO14443A, uid, &uidLength, 250);
  if (!success) return false;

  scannedUID = uidToString(uid, uidLength);
  Serial.print("Scanned UID = "); Serial.println(scannedUID);
  return true;
}

String uidToString(uint8_t *uid, uint8_t uidLength) {
  String result = "";
  for (uint8_t i = 0; i < uidLength; i++) {
    if (uid[i] < 0x10) result += "0";
    String byteText = String(uid[i], HEX);
    byteText.toUpperCase();
    result += byteText;
    if (i < uidLength - 1) result += ":";
  }
  return result;
}

// =====================================================
// OLED SCREENS
// =====================================================

void drawScreen() {
  switch (currentState) {
    case STATE_BOOT: drawBoot(); break;
    case STATE_WIFI_CONNECTING: drawWiFiConnecting(); break;
    case STATE_WIFI_PROVISIONING: drawWiFiProvisioning(); break;
    case STATE_PN532_LOADING: drawPn532Loading(); break;
    case STATE_DB_LOADING: drawDbLoading(); break;
    case STATE_NO_RESERVATION: drawNoReservation(); break;
    case STATE_READY_TO_SCAN: drawReadyToScan(); break;
    case STATE_NFC_UPDATING: drawNfcUpdating(); break;
    case STATE_ARRIVAL_APPROVED: drawArrivalApproved(); break;
    case STATE_WRONG: drawWrong(); break;
    case STATE_NFC_UPDATE_ERROR: drawNfcUpdateError(); break;
    case STATE_DB_ERROR: drawDbError(); break;
    case STATE_PN532_ERROR: drawPn532Error(); break;
  }
}

void drawBoot() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("SMART STICKER");
  display.setCursor(0, 18); display.println("Booting...");
  display.setCursor(0, 36); display.println("OLED + PN532");
  display.display();
}

void drawWiFiConnecting() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("SMART STICKER");
  display.setTextSize(2);
  display.setCursor(0, 22); display.println("WIFI");
  display.setTextSize(1);
  display.setCursor(0, 50); display.println("Connecting...");
  display.display();
}

void drawWiFiProvisioning() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("WIFI SETUP NEEDED");
  display.setCursor(0, 16); display.println("Connect to:");
  display.setTextSize(1);
  display.setCursor(0, 30); display.println("Stickeep-Setup");
  display.setCursor(0, 46); display.println("Then open browser");
  display.setCursor(0, 56); display.println("192.168.4.1");
  display.display();
}

void drawPn532Loading() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("SMART STICKER");
  display.setTextSize(2);
  display.setCursor(0, 20); display.println("PN532");
  display.setTextSize(1);
  display.setCursor(0, 50); display.println("Starting NFC...");
  display.display();
}

void drawDbLoading() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("DATABASE");
  display.setTextSize(2);
  display.setCursor(0, 24); display.println("LOADING");
  display.display();
}

void drawNoReservation() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("TODAY");
  display.setTextSize(2);
  display.setCursor(0, 20); display.println("NO");
  display.setCursor(0, 42); display.println("ORDER");
  display.display();
}

void drawReadyToScan() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("TODAY ORDER");
  display.setCursor(0, 13); display.print("Student:"); display.println(activeReservation.studentNumber);
  display.setCursor(0, 25);
  display.print(activeReservation.startTime); display.print("-"); display.println(activeReservation.endTime);
  display.setTextSize(2);
  display.setCursor(0, 45); display.println("SCAN");
  display.display();
}

void drawNfcUpdating() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("CARD SCANNED");
  display.setTextSize(2);
  display.setCursor(0, 20); display.println("CHECKING");
  display.setTextSize(1);
  display.setCursor(0, 50); display.println("with server...");
  display.display();
}

void drawArrivalApproved() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("ARRIVAL APPROVED");
  display.setCursor(0, 13); display.print("Student:"); display.println(activeReservation.studentNumber);
  display.setCursor(0, 30); display.print("NFC:"); display.println(activeReservation.nfcStatus);
  display.display();
}

void drawWrong() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(2);
  display.setCursor(0, 12); display.println("WRONG");
  display.setTextSize(1);
  display.setCursor(0, 45); display.println(lastScannedUID);
  display.display();
}

void drawNfcUpdateError() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("SERVER ERROR");
  display.setCursor(0, 20); display.println(dbErrorText);
  display.setCursor(0, 50); display.println("SCAN AGAIN");
  display.display();
}

void drawDbError() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("DB ERROR");
  display.setCursor(0, 20); display.println(dbErrorText);
  display.setCursor(0, 42); display.println("Check Serial");
  display.display();
}

void drawPn532Error() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0); display.println("PN532 ERROR");
  display.setCursor(0, 20); display.println("No firmware");
  display.setCursor(0, 42); display.println("Check I2C");
  display.display();
}

// =====================================================
// I2C DEBUG
// =====================================================

bool i2cDeviceExists(uint8_t address) {
  Wire.beginTransmission(address);
  return Wire.endTransmission() == 0;
}

void printI2CCheck() {
  Serial.println("===== I2C CHECK =====");
  Serial.print("OLED 0x3C: "); Serial.println(i2cDeviceExists(OLED_ADDR) ? "FOUND" : "MISSING");
  Serial.print("PN532 0x24: "); Serial.println(i2cDeviceExists(PN532_ADDR) ? "FOUND" : "MISSING");
}
