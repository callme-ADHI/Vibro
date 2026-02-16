/*
  Vibro BLE LED Controller
  ESP32 + NimBLE (Arduino Cloud Compatible)

  Device Name: vibro

  Service UUID:        6E400001-B5A3-F393-E0A9-E50E24DCCA9E
  Characteristic UUID: 6E400002-B5A3-F393-E0A9-E50E24DCCA9E

  Command:
  0x01 → Blink LED for 2 seconds
*/

#include <NimBLEDevice.h>

#define LED_PIN 13
#define DEVICE_NAME "vibro"

#define SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"

bool deviceConnected = false;
bool ledState = false;
unsigned long blinkStartTime = 0;
const unsigned long blinkDuration = 2000;  // 2 seconds

// ─────────────────────────────────────────
// Server Callbacks
// ─────────────────────────────────────────
class ServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) {
        deviceConnected = true;
        Serial.println("Device Connected");
    }

    void onDisconnect(NimBLEServer* pServer) {
        deviceConnected = false;
        Serial.println("Device Disconnected");

        NimBLEDevice::startAdvertising();
        Serial.println("Advertising restarted");
    }
};

// ─────────────────────────────────────────
// Characteristic Callbacks
// ─────────────────────────────────────────
class CharacteristicCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* pCharacteristic) {

        std::string value = pCharacteristic->getValue();

        if (value.length() > 0) {

            Serial.print("Received: ");
            for (size_t i = 0; i < value.length(); i++) {
                Serial.print((uint8_t)value[i], HEX);
                Serial.print(" ");
            }
            Serial.println();

            if ((uint8_t)value[0] == 0x01 || (uint8_t)value[0] == '1') {
                Serial.println("Command: BLINK LED");

                digitalWrite(LED_PIN, HIGH);
                ledState = true;
                blinkStartTime = millis();
            }
        }
    }
};

void setup() {

    Serial.begin(115200);
    Serial.println("Starting Vibro BLE...");

    pinMode(LED_PIN, OUTPUT);
    digitalWrite(LED_PIN, LOW);

    NimBLEDevice::init(DEVICE_NAME);
    NimBLEDevice::setPower(ESP_PWR_LVL_P9);

    // Create server
    NimBLEServer* pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(new ServerCallbacks());

    // Create service
    NimBLEService* pService = pServer->createService(SERVICE_UUID);

    // Create characteristic
    NimBLECharacteristic* pCharacteristic =
        pService->createCharacteristic(
            CHARACTERISTIC_UUID,
            NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
        );

    pCharacteristic->setCallbacks(new CharacteristicCallbacks());

    pService->start();

    // Proper advertising setup
    NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();

    NimBLEAdvertisementData advData;
    advData.setName(DEVICE_NAME);
    advData.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
    advData.addServiceUUID(SERVICE_UUID);

    pAdvertising->setAdvertisementData(advData);
    pAdvertising->start();

    Serial.println("BLE Advertising started");
}

void loop() {

    // Non-blocking LED timer
    if (ledState && (millis() - blinkStartTime > blinkDuration)) {
        digitalWrite(LED_PIN, LOW);
        ledState = false;
        Serial.println("LED OFF");
    }

    delay(10);
}
