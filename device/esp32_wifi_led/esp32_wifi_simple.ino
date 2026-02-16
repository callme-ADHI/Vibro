/*
  Vibro - WiFi LED Controller (Hotspot Mode)
  
  Instructions:
  1. Open Serial Monitor (115200 baud).
  2. Change WIFI_SSID to your Phone's Hotspot Name.
  3. Change WIFI_PASSWORD to your Hotspot Password.
  4. Upload.
  5. Wait for connection (LED will flash fast while connecting).
  6. Once connected, Serial Monitor will show IP Address (e.g., 192.168.43.100).
  7. Open Phone Browser and visit: http://<IP_ADDRESS>/blink
*/

#include <WiFi.h>
#include <WebServer.h>

// ── CONFIGURATION ──
const char* WIFI_SSID     = "Your_Phone_Hotspot_Name";      // CHANGE THIS
const char* WIFI_PASSWORD = "Your_Hotspot_Password";  // CHANGE THIS
#define LED_PIN 13

WebServer server(80);

void handleRoot() {
  server.send(200, "text/plain", "Vibro WiFi Ready. Go to /blink to flash LED.");
}

void handleBlink() {
  Serial.println("Command: BLINK LED (WiFi)");
  digitalWrite(LED_PIN, HIGH);
  delay(1000); // Blink for 1 second
  digitalWrite(LED_PIN, LOW);
  server.send(200, "text/plain", "Blinked!");
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  Serial.println();
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  // Blink fast while connecting
  while (WiFi.status() != WL_CONNECTED) {
    delay(250);
    digitalWrite(LED_PIN, !digitalRead(LED_PIN)); // Toggle
    Serial.print(".");
  }

  digitalWrite(LED_PIN, LOW); // Connected -> LED OFF
  Serial.println();
  Serial.println("WiFi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  server.on("/", handleRoot);
  server.on("/blink", handleBlink);
  
  server.begin();
  Serial.println("HTTP Server Started");
}

void loop() {
  server.handleClient();
}
