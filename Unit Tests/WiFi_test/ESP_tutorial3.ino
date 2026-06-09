#include "WiFi.h"

#define yellowLedPin 15   // Yellow LED - reserved
#define blueLedPin 22     // Blue LED - available / waiting

const char* ssid = "Thalia g";
const char* password = "xxxxx";

WiFiServer server(80);

String header = "";

bool seatReserved = false;

void setup() {
  Serial.begin(115200);

  pinMode(yellowLedPin, OUTPUT);
  pinMode(blueLedPin, OUTPUT);

  // Start every ESP32 reset as available
  seatReserved = false;

  digitalWrite(yellowLedPin, LOW);
  digitalWrite(blueLedPin, HIGH);

  WiFi.persistent(false);
  WiFi.setAutoReconnect(true);

  connectToWifi();

  server.begin();
  Serial.println("Web server started");
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi disconnected");

    blinkBlueLed();

    connectToWifi();
    return;
  }

  updateLeds();

  WiFiClient client = server.available();

  if (client) {
    Serial.println("New client connected");

    String currentLine = "";
    header = "";

    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        header += c;

        if (c == '\n') {
          if (currentLine.length() == 0) {

            // Only a real button press sends POST /reserve
            if (header.indexOf("POST /reserve") >= 0) {
              seatReserved = true;
              Serial.println("Seat reserved");
            }

            sendWebPage(client);

            break;
          }
          else {
            currentLine = "";
          }
        }
        else if (c != '\r') {
          currentLine += c;
        }
      }
    }

    client.stop();
    Serial.println("Client disconnected");
  }
}

void updateLeds() {
  if (seatReserved == false) {
    // Seat available - blue ON
    digitalWrite(blueLedPin, HIGH);
    digitalWrite(yellowLedPin, LOW);
  }
  else {
    // Seat reserved - yellow ON
    digitalWrite(blueLedPin, LOW);
    digitalWrite(yellowLedPin, HIGH);
  }
}

void blinkBlueLed() {
  digitalWrite(yellowLedPin, LOW);

  digitalWrite(blueLedPin, HIGH);
  delay(300);

  digitalWrite(blueLedPin, LOW);
  delay(300);
}

void sendWebPage(WiFiClient client) {
  client.println("HTTP/1.1 200 OK");
  client.println("Content-type:text/html; charset=UTF-8");
  client.println("Cache-Control: no-store, no-cache, must-revalidate");
  client.println("Pragma: no-cache");
  client.println("Expires: 0");
  client.println("Connection: close");
  client.println();

  client.println("<!DOCTYPE html>");
  client.println("<html>");
  client.println("<head>");
  client.println("<meta charset='UTF-8'>");
  client.println("<meta name='viewport' content='width=device-width, initial-scale=1'>");

  client.println("<style>");
  client.println("body { font-family: Arial; text-align: center; margin-top: 60px; background-color: #f7f7f7; }");
  client.println("h1 { font-size: 32px; }");
  client.println("p { font-size: 24px; }");
  client.println(".button { padding: 18px 32px; font-size: 24px; border: none; border-radius: 10px; background-color: #f1c40f; color: black; cursor: pointer; }");
  client.println(".status { font-size: 28px; font-weight: bold; margin-top: 30px; color: #d4a300; }");
  client.println(".available { font-size: 28px; font-weight: bold; margin-top: 30px; color: #0066cc; }");
  client.println("</style>");

  client.println("</head>");
  client.println("<body>");

  client.println("<h1>Reserved Seat System</h1>");

  if (seatReserved == false) {
    client.println("<p class='available'>Seat is available</p>");

    // Real button using POST, not a normal link
    client.println("<form action='/reserve' method='POST'>");
    client.println("<button class='button' type='submit'>Reserve Seat</button>");
    client.println("</form>");
  }
  else {
    client.println("<p class='status'>Seat Reserved</p>");
  }

  client.println("</body>");
  client.println("</html>");

  client.println();
}

void connectToWifi() {
  Serial.println("Resetting WiFi radio...");

  WiFi.disconnect(false);
  delay(500);

  WiFi.mode(WIFI_OFF);
  delay(1000);

  WiFi.mode(WIFI_STA);
  delay(1000);

  Serial.println("Connecting to WiFi...");
  WiFi.begin(ssid, password);

  int counter = 0;

  while (WiFi.status() != WL_CONNECTED && counter < 30) {
    blinkBlueLed();
    Serial.print(".");
    counter++;
  }

  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("Connected!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());

    updateLeds();
  }
  else {
    Serial.println("Failed to connect");
  }
}