void updateReservationsFromFirebase(bool forceUpdate) {
  if (WiFi.status() != WL_CONNECTED)
    return;

  if (!forceUpdate && millis() - lastFirebaseUpdate < firebaseUpdateInterval)
    return;

  lastFirebaseUpdate = millis();

  // שמירת מצב ישן כדי לבדוק האם באמת היה שינוי
  int oldReservationCount = reservationCount;

  String oldStart[MAX_RESERVATIONS];
  String oldEnd[MAX_RESERVATIONS];
  String oldStatus[MAX_RESERVATIONS];
  String oldStudentNumber[MAX_RESERVATIONS];

  for (int i = 0; i < reservationCount; i++) {
    oldStart[i] = resStart[i];
    oldEnd[i] = resEnd[i];
    oldStatus[i] = resStatus[i];
    oldStudentNumber[i] = resStudentNumber[i];
  }

  String today = getTodayDateString();

  Serial.print("Today = ");
  Serial.println(today);

  String url =
    "https://firestore.googleapis.com/v1/projects/" +
    String(firestoreProjectId) +
    "/databases/(default)/documents/seats/" +
    String(SEAT_ID) +
    "/reservations";

  HTTPClient http;
  http.begin(url);

  int httpCode = http.GET();

  if (httpCode != 200) {
    Serial.print("Firestore error: ");
    Serial.println(httpCode);
    Serial.println(http.getString());
    http.end();
    registerSyncFailure();
    return;
  }

  String payload = http.getString();

  StaticJsonDocument<20000> doc;
  DeserializationError error = deserializeJson(doc, payload);

  if (error) {
    Serial.print("JSON error: ");
    Serial.println(error.c_str());
    http.end();
    registerSyncFailure();
    return;
  }

  reservationCount = 0;

  JsonArray documents = doc["documents"].as<JsonArray>();

  for (JsonObject reservationDoc : documents) {
    if (reservationCount >= MAX_RESERVATIONS)
      break;

    JsonObject fields = reservationDoc["fields"];

    String date = fields["date"]["stringValue"].as<String>();

    if (date != today)
      continue;

    // Skip cancelled reservations — otherwise a cancelled booking still
    // shows this seat as reserved/occupied since only date/time overlap
    // was checked before, never the actual status.
    String status = fields["status"]["stringValue"].as<String>();
    if (status == "cancelled")
      continue;

    resStart[reservationCount] =
      fields["startTime"]["stringValue"].as<String>();

    resEnd[reservationCount] =
      fields["endTime"]["stringValue"].as<String>();

    resStatus[reservationCount] = status;

    resStudentNumber[reservationCount] =
      fields["studentNumber"]["stringValue"].as<String>();

    // Needed to render the real per-reservation QR code (see
    // DisplayManager.ino) instead of the old static placeholder image.
    resQrToken[reservationCount] =
      fields["qrToken"]["stringValue"].as<String>();

    Serial.println("----- Reservation -----");
    Serial.print("Start: ");
    Serial.println(resStart[reservationCount]);

    Serial.print("End: ");
    Serial.println(resEnd[reservationCount]);

    Serial.print("Status: ");
    Serial.println(resStatus[reservationCount]);

    Serial.print("Student: ");
    Serial.println(resStudentNumber[reservationCount]);

    reservationCount++;
  }

  Serial.print("Today reservations count = ");
  Serial.println(reservationCount);

  http.end();
  registerSyncSuccess();

  // בדיקה האם באמת היה שינוי בנתונים
  bool dataChanged = false;

  if (reservationCount != oldReservationCount) {
    dataChanged = true;
  }

  for (int i = 0; i < reservationCount; i++) {
    if (resStart[i] != oldStart[i] ||
        resEnd[i] != oldEnd[i] ||
        resStatus[i] != oldStatus[i] ||
        resStudentNumber[i] != oldStudentNumber[i]) {
      dataChanged = true;
      break;
    }
  }

  // עדכון מסך רק אם יש שינוי אמיתי
  if (currentState == STATE_MAIN_SCREEN && dataChanged) {
    drawMainScreenReservations();
  }
}

// Tracks repeated fetch failures so the display can warn that data is
// stale instead of silently showing old reservations forever.
int consecutiveSyncFailures = 0;
const int syncFailureWarningThreshold = 5;  // ~50s at the 10s poll interval

void registerSyncFailure() {
  consecutiveSyncFailures++;
  if (consecutiveSyncFailures == syncFailureWarningThreshold) {
    drawSyncWarning(true);
  }
}

void registerSyncSuccess() {
  if (consecutiveSyncFailures >= syncFailureWarningThreshold) {
    drawSyncWarning(false);
  }
  consecutiveSyncFailures = 0;
}