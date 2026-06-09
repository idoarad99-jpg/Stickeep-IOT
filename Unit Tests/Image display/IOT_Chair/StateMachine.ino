


int lastButtonState = HIGH;
unsigned long lastDebounceTime = 0;
const unsigned long debounceDelay = 200;

void readButtonAndUpdateState() {
  int buttonState = digitalRead(buttonPin);

  if (lastButtonState == HIGH && buttonState == LOW) {
    if (millis() - lastDebounceTime > debounceDelay) {
      nextState();
      lastDebounceTime = millis();
    }
  }

  lastButtonState = buttonState;
}

void nextState() {
  if (currentState == STATE_NORTHERN_LIGHTS) {
    currentState = STATE_MAIN_SCREEN;
  } else {
    currentState = (ScreenState)(currentState + 1);
  }
}