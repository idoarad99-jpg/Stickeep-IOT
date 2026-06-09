#include <TFT_eSPI.h> // Graphics and font library for ST7735 driver chip
#include <SPI.h>

//Led pins definition
#define redLedPin 15
#define greenLedPin 12
#define blueLedPin 2

//Touch pin definition
#define redTouchPin T9
#define greenTouchPin T8
#define blueTouchPin T7

#define potPin 13      // Potentiometer pin definition
#define PWMChannel 0   // PWM Channel def (maybe not needed)

// PWM requirments
const int freq = 5000;
const int resolution = 12; 

// Touch pins ints
int redTouchData = 0;
int greenTouchData = 0;
int blueTouchData = 0;

// Pontentiometer int
int potData = 0;
float voltage =0.0;

void setup() {
// declaring working pin modes (OUTPUT \ INPUT)
 pinMode(redLedPin,OUTPUT);
 pinMode(blueLedPin,OUTPUT);
 pinMode(greenLedPin,OUTPUT);
 pinMode(potPin,INPUT);

 // PWM pin setup
 ledcAttach(redLedPin,freq, resolution);
 ledcAttach(greenLedPin, freq, resolution);
 ledcAttach(blueLedPin, freq, resolution);
 Serial.begin(115200);
}

void loop() {
  // Collect Pot data and print it
  potData = analogRead(potPin);
  Serial.print("\tPotentiometer = ");
  Serial.println(potData);

  //  dutyCycle = map(potData, 0, 4095, 0, 255)  -> map the data insted 0-4095 -> 0-255
  voltage = (float)potData / 4095 * 3.3;
  Serial.print("\tVoltage = ");
  Serial.println(voltage);
  
  // Collect touch data and print it
  redTouchData = touchRead(redTouchPin);
  Serial.print("Touch");
  Serial.println(redTouchData);

  greenTouchData = touchRead(greenTouchPin);
  Serial.print(" : ");
  Serial.println(greenTouchData);

  blueTouchData = touchRead (blueTouchPin);
  Serial.print(" : ");
  Serial.println(blueTouchData);

  // Turn Led on if pin is touched
  if(redTouchData < 500) digitalWrite(redLedPin,HIGH);
  else digitalWrite(redLedPin,LOW);
  if(greenTouchData < 500) digitalWrite(greenLedPin,HIGH);
  else digitalWrite(greenLedPin,LOW);
  if(blueTouchData < 500) digitalWrite(blueLedPin,HIGH);
  else digitalWrite(blueLedPin,LOW);

 // PWM Write data 
  ledcWrite(redLedPin, potData);
  ledcWrite(greenLedPin, potData);
  ledcWrite(blueLedPin, potData);
}
