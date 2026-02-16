/*
  Vibro BLE LED Controller (NimBLE Version)
  Fixes standard BLE library compilation conflicts

  Device Name: vibro
  Blink Commands:
  0x01 → Blink 2 seconds
  0x02 → Blink 5 seconds
*/

#include <NimBLEDevice.h>

// ── Configuration ──
#define LED_PIN_A 13
#define LED_PIN_B 2
#define DEVICE_NAME "vibro"

#define SERVICE_UUID        "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define CHARACTERISTIC_UUID "6e400002-b5a3-f393-e0a9-e50e24dcca9e"

// ── State ──
bool deviceConnected = false;
bool ledActive = false;
unsigned long ledOffTime = 0;

// ── Server Callbacks ──
class MyServerCallbacks : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer* pServer) {
        deviceConnected = true;
        Serial.println(">>> App Connected");
    }

    void onDisconnect(NimBLEServer* pServer) {
        deviceConnected = false;
        Serial.println(">>> App Disconnected");
        
        // NimBLE auto-advertising can be handled or manually restarted
        NimBLEDevice::startAdvertising();
        Serial.println(">>> Advertising Restarted");
    }
};

// ── Characteristic Callbacks ──
class MyCallbacks : public NimBLECharacteristicCallbacks {
    void onWrite(NimBLECharacteristic* pCharacteristic) {
        std::string value = pCharacteristic->getValue();

        if (value.length() > 0) {
            uint8_t command = (uint8_t)value[0];
            Serial.print("Command Received: 0x");
            Serial.println(command, HEX);

            if (command == 0x01 || command == '1') {
                startLed(2000);
            } else if (command == 0x02 || command == '2') {
                startLed(5000);
            }
        }
    }

    void startLed(int durationMs) {
        digitalWrite(LED_PIN_A, HIGH);
        digitalWrite(LED_PIN_B, HIGH);
        ledOffTime = millis() + durationMs;
        ledActive = true;
        Serial.print(">>> LED ON for ");
        Serial.print(durationMs);
        Serial.println("ms");
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("Starting Vibro NimBLE...");

    pinMode(LED_PIN_A, OUTPUT);
    pinMode(LED_PIN_B, OUTPUT);
    digitalWrite(LED_PIN_A, LOW);
    digitalWrite(LED_PIN_B, LOW);

    // Initialize NimBLE Device
    NimBLEDevice::init(DEVICE_NAME);
    NimBLEDevice::setPower(ESP_PWR_LVL_P9); // Max power level

    // Create Server
    NimBLEServer* pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    // Create Service
    NimBLEService* pService = pServer->createService(SERVICE_UUID);

    // Create Characteristic
    NimBLECharacteristic* pCharacteristic = pService->createCharacteristic(
        CHARACTERISTIC_UUID,
        NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR
    );

    pCharacteristic->setCallbacks(new MyCallbacks());

    // Start Service
    pService->start();

    // Advertising setup
    NimBLEAdvertising* pAdvertising = NimBLEDevice::getAdvertising();
    
    // Set Appearance and Data
    NimBLEAdvertisementData advData;
    advData.setName(DEVICE_NAME);
    advData.setFlags(BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP);
    advData.addServiceUUID(SERVICE_UUID);
    pAdvertising->setAdvertisementData(advData);

    pAdvertising->start();
    Serial.println("Vibro NimBLE Ready. Waiting for connection...");
}

void loop() {
    // Non-blocking LED Control
    if (ledActive && millis() > ledOffTime) {
        digitalWrite(LED_PIN_A, LOW);
        digitalWrite(LED_PIN_B, LOW);
        ledActive = false;
        Serial.println(">>> LED OFF");
    }

    delay(10);
}
