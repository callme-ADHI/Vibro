/*
  Vibro - ESP32 BLE LED Controller
  Firmware Version: 1.0.0
  Hardware: ESP32 Dev Board + LED on GPIO 2
  
  Logic:
  1. Advertise as "Vibro_Device"
  2. Accept 0x01 on Characteristic to trigger LED
  3. LED stays ON for 2 seconds (Non-blocking)
  4. Auto-restarts advertising on disconnect
*/

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ── CONFIG ──
#define LED_PIN 2           // Built-in LED usually GPIO 2
#define BLINK_Duration 2000 // ms
#define SERVICE_UUID        "6e400001-b5a3-f393-e0a9-e50e24dcca9e"
#define CHARACTERISTIC_UUID "6e400002-b5a3-f393-e0a9-e50e24dcca9e"

// ── STATE ──
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;
unsigned long ledTimer = 0;
bool ledState = false;

// ── CALLBACKS ──
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("📱 Device Connected");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("❌ Device Disconnected");
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();

      if (value.length() > 0) {
        Serial.print("📥 Received: ");
        for (int i = 0; i < value.length(); i++)
          Serial.print(value[i]);
        Serial.println();

        // Check for Command 0x01
        if (value[0] == 0x01) {
          Serial.println("💡 CMD: BLINK LED");
          digitalWrite(LED_PIN, HIGH);
          ledState = true;
          ledTimer = millis(); // Start timer
        }
      }
    }
};

// ── SETUP ──
void setup() {
  Serial.begin(115200);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Initialize BLE
  BLEDevice::init("Vibro_Device");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_WRITE |
                      BLECharacteristic::PROPERTY_WRITE_NR
                    );

  pCharacteristic->setCallbacks(new MyCallbacks());

  // Start Service
  pService->start();

  // Start Advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);  // set value to 0x00 to not advertise this parameter
  BLEDevice::startAdvertising();
  
  Serial.println("✅ Vibro BLE Ready! Waiting for connection...");
}

// ── LOOP ──
void loop() {
  // Handle Non-Blocking Blink
  if (ledState) {
    if (millis() - ledTimer >= BLINK_Duration) {
      digitalWrite(LED_PIN, LOW);
      ledState = false;
      Serial.println("🌑 LED OFF");
    }
  }

  // Handle Disconnection (Restart Advertising)
  if (!deviceConnected && oldDeviceConnected) {
      delay(500); // Give bluetooth stack chance to get ready
      pServer->startAdvertising(); 
      Serial.println("📡 Restarting Advertising...");
      oldDeviceConnected = deviceConnected;
  }
  
  // Handle Connection
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }
}
