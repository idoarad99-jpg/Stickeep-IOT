#include <SPI.h>
#include <TFT_eSPI.h>
#include <JPEGDecoder.h>
#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <Preferences.h>
#include "time.h"
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <qrcode.h>  // "QRCode" by Richard Moore — Library Manager search "QRCode"

#include "Main_screen135x240.h"
#include "Thank_you.h"
#include "Reserved.h"
// QR_image.h is no longer used — STATE_QR_SCAN now renders a real,
// per-reservation QR code (see DisplayManager.ino's drawQrScreen()/ the
// qrcode.h include above) instead of a static placeholder image.

String generateSeatSerial(String seatId);

void connectToWiFi();
void maintainWifiConnection();
void initTime();
void updateDateTime();
void updateWifiStatusText();

void updateReservationsFromFirebase(bool forceUpdate);

void updateStateMachine();

void updateScreen();

void drawMainScreenReservations();

void drawDateTimeStatus();

void setupNfc();
bool tryReadNfcCard(String &cardIdOut);
bool confirmNfcArrival(String cardId);

int getCurrentMinutes();
String getTodayDateString();
int timeToMinutes(String timeStr);

#define minimum(a,b) (((a) < (b)) ? (a) : (b))

TFT_eSPI tft = TFT_eSPI();

// WiFi — credentials are no longer hardcoded here. See WifiManager.ino:
// the device is provisioned via its own captive-portal setup page
// (supports plain WPA2-PSK for hotspot/home WiFi, and WPA2-Enterprise for
// eduroam), with credentials stored in flash. Hold WIFI_RESET_PIN low at
// boot to re-enter provisioning (e.g. after moving the device).
String wifiStatusText = "Off";
String previousWifiStatusText = "";
const int WIFI_RESET_PIN = -1;  // set to a real GPIO once a reset button is wired; -1 disables this

// WiFi provisioning state (see WifiManager.ino). Declared here, not
// there, since setup()/loop() in this file reference them and Arduino
// only auto-generates cross-file prototypes for functions, not variables.
Preferences wifiPrefs;
WebServer provisioningServer(80);
DNSServer dnsServer;
bool wifiProvisioningActive = false;

const char* provisioningApSsid = "Stickeep-Setup";
const byte DNS_PORT = 53;
const int NET_TYPE_NONE = 0;
const int NET_TYPE_PLAIN = 1;
const int NET_TYPE_ENTERPRISE = 2;

 //Time and date
String currentDateText = "";
String currentTimeText = "";

//Batrry State
String batteryText = "--%";
String previousBatteryText = "";

// Firebase
const char* firestoreProjectId = "stickeep";
const char* SEAT_ID = "SEAT_T2_1";

// Cloud Functions — see stickeep_app/functions/index.js. Both are gated
// by the same shared secret. Deployed and live as of 2026-07-12 — ask the
// app team for the current DEVICE_API_KEY value directly (not committed
// here on purpose, since this file is version-controlled).
const char* nfcConfirmFunctionUrl = "https://confirmnfcarrival-ehu6egweoa-uc.a.run.app";
const char* deviceApiKey = "REPLACE_WITH_DEVICE_API_KEY";

// NFC reader (MFRC522, SPI) — confirm these pins match the actual wiring.
const int NFC_SS_PIN = 5;
const int NFC_RST_PIN = 27;

// Chair serial
String seatSerialNumber = "";

// Button
const int qrButtonPin = 15;

// States
enum ScreenState {
  STATE_MAIN_SCREEN,
  STATE_QR_SCAN,
  STATE_THANK_YOU,
  STATE_RESERVED
};

ScreenState currentState = STATE_MAIN_SCREEN;
ScreenState previousState = STATE_RESERVED;

// Reservations
const int MAX_RESERVATIONS = 8;

String resStart[MAX_RESERVATIONS];
String resEnd[MAX_RESERVATIONS];
String resStatus[MAX_RESERVATIONS];
String resStudentNumber[MAX_RESERVATIONS];
String resQrToken[MAX_RESERVATIONS];

int reservationCount = 0;

String activeStartTime = "";
String activeEndTime = "";
String activeStudentNumber = "";
String activeQrToken = "";

// Timers
unsigned long lastFirebaseUpdate = 0;
const unsigned long firebaseUpdateInterval = 10000;

unsigned long lastTimeUpdate = 0;
const unsigned long timeUpdateInterval = 1000;

unsigned long thankYouStartTime = 0;
const unsigned long thankYouDuration = 60000;

void setup() {
  Serial.begin(115200);

  pinMode(qrButtonPin, INPUT_PULLUP);
  if (WIFI_RESET_PIN >= 0) {
    pinMode(WIFI_RESET_PIN, INPUT_PULLUP);
  }

  seatSerialNumber = generateSeatSerial(String(SEAT_ID));
  Serial.print("Seat SN = ");
  Serial.println(seatSerialNumber);

  tft.begin();
  tft.setRotation(1);
  tft.fillScreen(TFT_BLACK);

  wifiPrefs.begin("wifi", false);
  connectToWiFi();
  initTime();

  setupNfc();

  updateReservationsFromFirebase(true);
  updateScreen();

  previousState = currentState;
}

void loop() {
  maintainWifiConnection();

  // Provisioning mode takes over the device (captive portal) until the
  // installer saves credentials and it restarts — skip normal operation
  // while that's happening.
  if (wifiProvisioningActive) return;

  updateWifiStatusText();
  updateBatteryStatus();
  updateDateTime();

  updateReservationsFromFirebase(false);

  updateStateMachine();

  if (currentState != previousState) {
    updateScreen();
    previousState = currentState;
  }
}