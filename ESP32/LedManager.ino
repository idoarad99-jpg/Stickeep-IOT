// ====================================================
// Status LED (discrete common-anode RGB LED, 3 PWM pins)
// ====================================================
//
// Wiring: common leg (longest) -> 5V, R -> LED_R_PIN (GPIO25),
// G -> LED_G_PIN (GPIO26), B -> LED_B_PIN (GPIO27), each through its
// inline current-limiting resistor.
//
// This is a plain 4-leg RGB LED, not an addressable WS2812/SK6812 — no
// data protocol, just three PWM brightness channels. Common ANODE means
// each color pin is active-LOW: to light a color, drive its GPIO low
// (more precisely, a *lower* PWM value = brighter, since the pin sinks
// current away from the shared 5V leg) — the opposite of a common-
// cathode LED. setLedColor() below takes normal 0-255 "how bright"
// values and inverts them internally so the rest of the file can think
// in normal (higher = brighter) terms.
//
// Note: an incorrect *QR* scan can't be shown here — that mismatch is
// detected entirely on the student's phone (scanner_screen.dart) and
// never reaches the device. Only NFC mismatches are visible to the
// firmware, so only those trigger the red decline blink.

const int LED_R_PIN = 25;
const int LED_G_PIN = 26;
const int LED_B_PIN = 27;

// Transient events (NFC success/decline) briefly override whatever the
// base state color would be, then fall back automatically.
enum LedEvent { LED_EVENT_NONE, LED_EVENT_SUCCESS, LED_EVENT_DECLINE };
LedEvent ledEvent = LED_EVENT_NONE;
unsigned long ledEventStart = 0;
const unsigned long ledSuccessDuration = 3000;
const unsigned long ledDeclineDuration = 1500;  // matches drawNfcDeclined()'s on-screen duration

// Only rewrite the PWM duty cycles when the color actually changes.
int lastR = -1, lastG = -1, lastB = -1;

void setupLed() {
  pinMode(LED_R_PIN, OUTPUT);
  pinMode(LED_G_PIN, OUTPUT);
  pinMode(LED_B_PIN, OUTPUT);
  analogWrite(LED_R_PIN, 255);  // common anode: 255 = off
  analogWrite(LED_G_PIN, 255);
  analogWrite(LED_B_PIN, 255);
  Serial.println("Status LED initialized (common-anode RGB, GPIO25/26/27)");
}

void triggerLedSuccess() {
  ledEvent = LED_EVENT_SUCCESS;
  ledEventStart = millis();
}

void triggerLedDecline() {
  ledEvent = LED_EVENT_DECLINE;
  ledEventStart = millis();
}

// r/g/b: 0-255, higher = brighter (normal sense) — inverted here for
// the common-anode wiring.
void setLedColor(int r, int g, int b) {
  if (r == lastR && g == lastG && b == lastB) return;
  lastR = r;
  lastG = g;
  lastB = b;
  analogWrite(LED_R_PIN, 255 - r);
  analogWrite(LED_G_PIN, 255 - g);
  analogWrite(LED_B_PIN, 255 - b);
}

// Called every loop() iteration, but only actually writes to the LED
// when the target color changes (see setLedColor).
void updateLedState() {
  bool blinkOn = (millis() / 400) % 2 == 0;

  // WiFi/communication fault takes priority over everything else — it's
  // an ongoing condition, not a one-off event.
  if (WiFi.status() != WL_CONNECTED) {
    setLedColor(255, 0, 0);
    return;
  }

  if (ledEvent != LED_EVENT_NONE) {
    unsigned long eventDuration =
        ledEvent == LED_EVENT_SUCCESS ? ledSuccessDuration : ledDeclineDuration;

    if (millis() - ledEventStart >= eventDuration) {
      ledEvent = LED_EVENT_NONE;
    } else {
      if (ledEvent == LED_EVENT_SUCCESS) {
        // Blinking green — arrival confirmed (card or QR matched)
        setLedColor(0, blinkOn ? 255 : 0, 0);
      } else {
        // Decline blinks red instead of staying solid, so it reads as a
        // brief alert rather than the same steady red as a WiFi fault.
        setLedColor(blinkOn ? 255 : 0, 0, 0);
      }
      return;
    }
  }

  switch (currentState) {
    case STATE_MAIN_SCREEN:
      setLedColor(0, 255, 0);  // free — solid green
      break;
    case STATE_QR_SCAN:
      // Reservation upcoming/active, awaiting arrival — blinking blue
      setLedColor(0, 0, blinkOn ? 255 : 0);
      break;
    case STATE_THANK_YOU:
    case STATE_RESERVED:
      setLedColor(0, 0, 255);  // occupied — solid blue
      break;
  }
}
