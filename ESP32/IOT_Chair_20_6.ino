#include <SPI.h>
#include <TFT_eSPI.h>
#include <JPEGDecoder.h>
#include <WiFi.h>
#include "time.h"
#include <HTTPClient.h>
#include <ArduinoJson.h>

#include "Main_screen135x240.h"
#include "QR_image.h"
#include "Thank_you.h"
#include "Reserved.h"

String generateSeatSerial(String seatId);

void connectToWiFi();
void initTime();
void updateDateTime();
void updateWifiStatusText();

void updateReservationsFromFirebase(bool forceUpdate);

void updateStateMachine();

void updateScreen();

void drawMainScreenReservations();

void drawDateTimeStatus();

int getCurrentMinutes();
String getTodayDateString();
int timeToMinutes(String timeStr);

#define minimum(a,b) (((a) < (b)) ? (a) : (b))

TFT_eSPI tft = TFT_eSPI();

// WiFi
const char* ssid = "Home";
const char* password = "0558836576";
String wifiStatusText = "Off";
String previousWifiStatusText = "";

 //Time and date
String currentDateText = "";
String currentTimeText = "";

//Batrry State
String batteryText = "--%";
String previousBatteryText = "";

// Firebase
const char* firestoreProjectId = "stickeep";
const char* SEAT_ID = "SEAT_T2_1";

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

int reservationCount = 0;

String activeStartTime = "";
String activeEndTime = "";
String activeStudentNumber = "";

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

  seatSerialNumber = generateSeatSerial(String(SEAT_ID));
  Serial.print("Seat SN = ");
  Serial.println(seatSerialNumber);

  tft.begin();
  tft.setRotation(1);
  tft.fillScreen(TFT_BLACK);

  connectToWiFi();
  initTime();

  updateReservationsFromFirebase(true);
  updateScreen();

  previousState = currentState;
}

void loop() {
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