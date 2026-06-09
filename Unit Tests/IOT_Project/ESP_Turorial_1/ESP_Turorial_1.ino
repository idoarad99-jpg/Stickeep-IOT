
#include <TFT_eSPI.h> // Graphics and font library for ST7735 driver chip
#include <SPI.h>

int led = 2;
int led2 = 13;
int btn = 15;
int btn_counter = 0;

void setup() {
  pinMode(led,OUTPUT);
  pinMode(led2,OUTPUT);
  pinMode(btn,INPUT_PULLUP);
  Serial.begin(115200);
}

void loop() {
  if (digitalRead(btn) == LOW) {
    btn_counter += 1;
    Serial.print("Count");
   // מניעת ספירה כפולה מלחיצה אחת
  }

  if (btn_counter == 2) {
    btn_counter = 0;
  }

  if (btn_counter == 0) {
    led_blink();
  }
  else if (btn_counter == 1) {
    led_blink_switch();
  }
}

void led_blink() {
  Serial.println("Plan1");
  digitalWrite(led, HIGH);
  digitalWrite(led2, HIGH);
  //Serial.println("Welcome to IoT Development...");
  delay(1000);

  digitalWrite(led, LOW);
  digitalWrite(led2, LOW);
  //Serial.println("With ESP32");
  delay(1000);
}

void led_blink_switch() {
  Serial.println("Plan2");
  digitalWrite(led, HIGH);
  digitalWrite(led2, LOW);
  //Serial.println("Welcome to IoT Development...");
  delay(1000);

  digitalWrite(led, LOW);
  digitalWrite(led2, HIGH);
  //Serial.println("With ESP32");
  delay(1000);
}