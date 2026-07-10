// ====================================================
// WiFi Manager
// ====================================================
//
// Replaces the old hardcoded single-network connectToWiFi(). Supports:
//   - Plain WPA2-PSK networks (home WiFi, phone hotspot)
//   - WPA2-Enterprise (eduroam) — needs identity/username/password, not
//     just SSID+password
//   - Re-provisioning without reflashing: on first boot (or if held
//     during boot, see WIFI_RESET_PIN), the device starts its own access
//     point with a simple web form to enter whichever network applies,
//     saved to flash (NVS) via Preferences.
//   - Auto-reconnect: if WiFi drops during normal operation, the device
//     retries instead of staying disconnected forever.
//
// Uses only built-in ESP32 Arduino core libraries (WiFi, Preferences,
// WebServer, DNSServer, esp_wpa2.h) — no extra libraries to install for
// this part.

#include "esp_wpa2.h"

// wifiPrefs, provisioningServer, dnsServer, wifiProvisioningActive, and
// the NET_TYPE_*/provisioningApSsid/DNS_PORT constants are declared in
// the main sketch (IOT_Chair_20_6.ino) instead of here: Arduino only
// auto-generates cross-file prototypes for functions, not global
// variables, and the main .ino always compiles first — so anything
// setup()/loop() touch (wifiPrefs, wifiProvisioningActive) has to be
// declared there, not in this file, or the build fails.

unsigned long lastReconnectAttempt = 0;
const unsigned long reconnectRetryInterval = 15000;

void startProvisioningPortal();
void handleProvisioningRoot();
void handleProvisioningSave();
bool tryConnectWithStoredCredentials(unsigned long timeoutMs);

void connectToWiFi() {
  WiFi.mode(WIFI_STA);

  int netType = wifiPrefs.getInt("netType", NET_TYPE_NONE);

  bool holdingResetButton =
      (WIFI_RESET_PIN >= 0) && (digitalRead(WIFI_RESET_PIN) == LOW);

  if (netType == NET_TYPE_NONE || holdingResetButton) {
    Serial.println(holdingResetButton
                        ? "WiFi reset button held — entering provisioning"
                        : "No stored WiFi credentials — entering provisioning");
    startProvisioningPortal();
    return;
  }

  Serial.println("Connecting to stored WiFi network...");
  if (tryConnectWithStoredCredentials(20000)) {
    wifiStatusText = "OK";
    Serial.println("WiFi connected");
  } else {
    Serial.println("Failed to connect with stored credentials — entering provisioning");
    startProvisioningPortal();
  }
}

bool tryConnectWithStoredCredentials(unsigned long timeoutMs) {
  int netType = wifiPrefs.getInt("netType", NET_TYPE_NONE);
  if (netType == NET_TYPE_NONE) return false;

  String ssid = wifiPrefs.getString("ssid", "");

  if (netType == NET_TYPE_PLAIN) {
    String password = wifiPrefs.getString("password", "");
    WiFi.begin(ssid.c_str(), password.c_str());
  } else {
    // WPA2-Enterprise (eduroam): needs identity + username + password,
    // set via the IDF-level esp_wifi_sta_wpa2_ent_* calls — plain
    // WiFi.begin(ssid, password) can't do this.
    String identity = wifiPrefs.getString("identity", "");
    String username = wifiPrefs.getString("username", "");
    String password = wifiPrefs.getString("password", "");

    esp_wifi_sta_wpa2_ent_set_identity((uint8_t *)identity.c_str(), identity.length());
    esp_wifi_sta_wpa2_ent_set_username((uint8_t *)username.c_str(), username.length());
    esp_wifi_sta_wpa2_ent_set_password((uint8_t *)password.c_str(), password.length());
    esp_wifi_sta_wpa2_ent_enable();
    WiFi.begin(ssid.c_str());
  }

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
    delay(300);
    Serial.print(".");
  }
  Serial.println();

  return WiFi.status() == WL_CONNECTED;
}

// Called every loop() iteration (see IOT_Chair_20_6.ino). Non-blocking:
// only attempts a reconnect every reconnectRetryInterval so it doesn't
// stall the rest of the state machine while retrying.
void maintainWifiConnection() {
  if (wifiProvisioningActive) {
    dnsServer.processNextRequest();
    provisioningServer.handleClient();
    return;
  }

  if (WiFi.status() == WL_CONNECTED) return;

  unsigned long now = millis();
  if (now - lastReconnectAttempt < reconnectRetryInterval) return;
  lastReconnectAttempt = now;

  Serial.println("WiFi disconnected — attempting reconnect...");
  tryConnectWithStoredCredentials(8000);
}

// ---- Captive portal ----

void startProvisioningPortal() {
  wifiProvisioningActive = true;
  wifiStatusText = "Setup";

  WiFi.mode(WIFI_AP);
  WiFi.softAP(provisioningApSsid);

  dnsServer.start(DNS_PORT, "*", WiFi.softAPIP());

  provisioningServer.on("/", handleProvisioningRoot);
  provisioningServer.on("/save", HTTP_POST, handleProvisioningSave);
  provisioningServer.onNotFound(handleProvisioningRoot);  // captive portal redirect
  provisioningServer.begin();

  Serial.print("Provisioning AP started: ");
  Serial.println(provisioningApSsid);
  Serial.print("Connect to it, then open: http://");
  Serial.println(WiFi.softAPIP());
}

void handleProvisioningRoot() {
  String html =
      "<html><body style='font-family:sans-serif;padding:16px'>"
      "<h2>Stickeep seat WiFi setup</h2>"
      "<form action='/save' method='POST'>"
      "<label>Network type:</label><br>"
      "<select name='netType'>"
      "<option value='1'>Plain (home WiFi / hotspot)</option>"
      "<option value='2'>Enterprise (eduroam)</option>"
      "</select><br><br>"
      "<label>Network name (SSID):</label><br>"
      "<input name='ssid' type='text'><br><br>"
      "<label>Identity (enterprise only, often same as username):</label><br>"
      "<input name='identity' type='text'><br><br>"
      "<label>Username (enterprise only):</label><br>"
      "<input name='username' type='text'><br><br>"
      "<label>Password:</label><br>"
      "<input name='password' type='password'><br><br>"
      "<button type='submit'>Save and connect</button>"
      "</form></body></html>";
  provisioningServer.send(200, "text/html", html);
}

void handleProvisioningSave() {
  int netType = provisioningServer.arg("netType").toInt();
  String ssid = provisioningServer.arg("ssid");
  String identity = provisioningServer.arg("identity");
  String username = provisioningServer.arg("username");
  String password = provisioningServer.arg("password");

  wifiPrefs.putInt("netType", netType);
  wifiPrefs.putString("ssid", ssid);
  wifiPrefs.putString("identity", identity);
  wifiPrefs.putString("username", username);
  wifiPrefs.putString("password", password);

  provisioningServer.send(
      200, "text/html",
      "<html><body style='font-family:sans-serif;padding:16px'>"
      "<h3>Saved. Restarting...</h3></body></html>");

  delay(1000);
  ESP.restart();
}
