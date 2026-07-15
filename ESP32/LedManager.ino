// ====================================================
// Status LED (single WS2812/SK6812 addressable RGB LED)
// ====================================================
//
// Wiring: DIN -> LED_PIN (GPIO 25), VDD -> 5V, GND -> GND.
// DOUT is unused (single LED, not daisy-chained).
//
// Note: an incorrect *QR* scan can't be shown here — that mismatch is
// detected entirely on the student's phone (scanner_screen.dart) and
// never reaches the device. Only NFC mismatches are visible to the
// firmware, so only those trigger the red decline blink.

#include <Adafruit_NeoPixel.h>

const int LED_PIN = 25;

Adafruit_NeoPixel statusLed(1, LED_PIN, NEO_GRB + NEO_KHZ800);

// Transient events (NFC success/decline) briefly override whatever the
// base state color would be, then fall back automatically.
enum LedEvent { LED_EVENT_NONE, LED_EVENT_SUCCESS, LED_EVENT_DECLINE };
LedEvent ledEvent = LED_EVENT_NONE;
unsigned long ledEventStart = 0;
const unsigned long ledEventDuration = 1500;  // matches drawNfcDeclined()'s on-screen duration

// Only call statusLed.show() when the color actually changes — it briefly
// disables interrupts to bit-bang precise timing to the LED, and doing
// that on every single loop() iteration (rather than only on an actual
// change) was found to disrupt the PN532's I2C reads.
uint32_t lastAppliedColor = 0xFFFFFFFF;  // sentinel that never matches a real color

void setupLed() {
  statusLed.begin();
  statusLed.setBrightness(80);
  statusLed.show();  // off until the first updateLedState()
  Serial.println("Status LED initialized (GPIO25)");
}

void triggerLedSuccess() {
  ledEvent = LED_EVENT_SUCCESS;
  ledEventStart = millis();
}

void triggerLedDecline() {
  ledEvent = LED_EVENT_DECLINE;
  ledEventStart = millis();
}

void applyLedColor(uint32_t color) {
  if (color == lastAppliedColor) return;
  lastAppliedColor = color;
  statusLed.setPixelColor(0, color);
  statusLed.show();
}

// Called every loop() iteration, but only actually writes to the LED
// when the target color changes (see applyLedColor) — cheap to call
// often, doesn't interfere with I2C.
void updateLedState() {
  bool blinkOn = (millis() / 400) % 2 == 0;

  // WiFi/communication fault takes priority over everything else — it's
  // an ongoing condition, not a one-off event.
  if (WiFi.status() != WL_CONNECTED) {
    applyLedColor(statusLed.Color(255, 0, 0));
    return;
  }

  if (ledEvent != LED_EVENT_NONE) {
    if (millis() - ledEventStart >= ledEventDuration) {
      ledEvent = LED_EVENT_NONE;
    } else {
      if (ledEvent == LED_EVENT_SUCCESS) {
        applyLedColor(statusLed.Color(0, 255, 0));
      } else {
        // Decline blinks red instead of staying solid, so it reads as a
        // brief alert rather than the same steady red as a WiFi fault.
        applyLedColor(blinkOn ? statusLed.Color(255, 0, 0) : 0);
      }
      return;
    }
  }

  switch (currentState) {
    case STATE_MAIN_SCREEN:
      applyLedColor(statusLed.Color(0, 0, 255));  // free — solid blue
      break;
    case STATE_QR_SCAN:
      // Reservation upcoming/active, awaiting arrival — blinking blue
      applyLedColor(blinkOn ? statusLed.Color(0, 0, 255) : 0);
      break;
    case STATE_THANK_YOU:
    case STATE_RESERVED:
      applyLedColor(statusLed.Color(255, 150, 0));  // occupied — solid yellow
      break;
  }
}
