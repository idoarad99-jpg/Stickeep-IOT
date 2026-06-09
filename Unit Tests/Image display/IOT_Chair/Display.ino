void updateScreen() {
  tft.fillScreen(TFT_BLACK);

  switch (currentState) {

    case STATE_MAIN_SCREEN:
      Serial.println("State: MAIN_SCREEN");
      tft.setRotation(1);
      drawArrayJpeg(Main_screen135x240, sizeof(Main_screen135x240), 0, 0);
      drawMainScreenData();
      break;

    case STATE_EAGLE:
      Serial.println("State: EAGLE");
      tft.setRotation(0);
      drawArrayJpeg(EagleEye, sizeof(EagleEye), 0, 16);
      break;

    case STATE_TIGER:
      Serial.println("State: TIGER");
      tft.setRotation(0);
      drawArrayJpeg(Tiger, sizeof(Tiger), 4, 0);
      break;

    case STATE_BABOON:
      Serial.println("State: BABOON");
      tft.setRotation(1);
      drawArrayJpeg(Baboon, sizeof(Baboon), 0, 4);
      break;

    case STATE_MOUSE:
      Serial.println("State: MOUSE");
      tft.setRotation(1);
      drawArrayJpeg(Mouse160, sizeof(Mouse160), 0, 11);
      break;

    case STATE_NORTHERN_LIGHTS:
      Serial.println("State: NORTHERN_LIGHTS");
      tft.setRotation(1);
      drawArrayJpeg(northn_lights, sizeof(northn_lights), 0, 0);
      break;
  }
}