
#include <TFT_eSPI.h> // Graphics and font library for ST7735 driver chip
#include <SPI.h>

int led = 2;
void setup() {
  pinMode(led,OUTPUT);
  Serial.Begin(115200);
}

void loop() {
  digitalWrite(led, HIGH);
  Serial.print("Welcome to IoT Development...")
  delay(1000)

digitalWrite(led, LOW);
  Serial.print("With ESP32")
  delay(1000)
}