#include <TFT_eSPI.h> // Graphics and font library for ST7735 driver chip
#include <SPI.h>
#include "WiFi.h"


#define redLedPin 15
#define greenLedPin 12
#define blueLedPin 2


void setup() {
  pinMode(redLedPin,OUTPUT);
 pinMode(blueLedPin,OUTPUT);
 pinMode(greenLedPin,OUTPUT);
 Serial.begin(115200);
 WiFi.mode(WIFI_STA);
 WiFi.disconnect();
 delay(1000);

}

void loop() {
  Serial.println("Scanning avaiable networks...");
  digitalWrite(redLedPin,HIGH);
  digitalWrite(greenLedPin,LOW);
  int n = WiFi.scanNetworks();
  if(n!=0){
    digitalWrite(redLedPin,LOW);
    digitalWrite(greenLedPin,HIGH);
    Serial.print(n); Serial.println(" networks found");
    for ( int i=0; i<n; ++i){
    Serial.print("network "); Serial.print(i + 1 );  Serial.print(" :");
    Serial.print(WiFi.SSID(i)); // Wifi network name
    Serial.print(" ("); Serial.print(WiFi.RSSI(i)); Serial.print(")");
    Serial.println((WiFi.encryptionType(i) == WIFI_AUTH_OPEN) ? "open" :"***");
    delay(50);
    }
  }
  else{
    Serial.println(" no available networks found");
    digitalWrite(redLedPin,LOW);
    digitalWrite(greenLedPin,LOW);
  }
  Serial.println("\n---------------------------------------------------\n");
  delay(5000);
}