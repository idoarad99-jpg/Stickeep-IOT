#include <SPI.h>
#include <TFT_eSPI.h>
#include <JPEGDecoder.h>
#include <WiFi.h>
#include "time.h"

#include "jpeg1.h"
#include "jpeg2.h"
#include "jpeg3.h"
#include "jpeg4.h"
#include "jpeg5.h"
#include "Main_screen135x240.h"

#define minimum(a,b) (((a) < (b)) ? (a) : (b))


#define potPin 32

int lastBatteryPercent = -1;


const char* ssid = "Shani";
const char* password = "0542515423";

//Wifi Update Time
unsigned long lastTimeUpdate = 0;
const unsigned long timeUpdateInterval = 1000;

 //Battry Update Time
unsigned long lastBatteryUpdate = 0;
const unsigned long batteryUpdateInterval = 100;

TFT_eSPI tft = TFT_eSPI();

const int buttonPin = 15;


enum ScreenState {
  STATE_MAIN_SCREEN,
  STATE_EAGLE,
  STATE_TIGER,
  STATE_BABOON,
  STATE_MOUSE,
  STATE_NORTHERN_LIGHTS
};

ScreenState currentState = STATE_MAIN_SCREEN;
ScreenState previousState = STATE_NORTHERN_LIGHTS;


// נתונים לדוגמה למסך הראשי
String wifiStatus = "OK";
String serialNumber = "SN001";
int batteryPercent = 87;
String currentDate = "02/06/26";
String currentTime = "11:23";

void setup() {
  Serial.begin(115200);

  pinMode(buttonPin, INPUT_PULLUP);
  pinMode(potPin, INPUT);

  tft.begin();
  tft.setRotation(1);
  tft.fillScreen(TFT_BLACK);

  connectToWiFi();
  initTime(); 

  updateScreen();
  previousState = currentState;

  lastBatteryUpdate = 0;
  lastBatteryPercent = -1;
  updateBatteryFromPot();
  
}

void loop() {
  readButtonAndUpdateState();
  updateBatteryFromPot();
  updateDateTime();

  if (currentState != previousState) {
    updateScreen();
    previousState = currentState;
  }
}