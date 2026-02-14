# Vibro ESP32 BLE LED Controller

Production-grade firmware for controlling an LED via Bluetooth Low Energy (BLE) from the Vibro Flutter app.

## 🚀 Deployment Steps

1.  **Install Arduino IDE**
2.  **Add ESP32 Board Manager URL:**
    `https://dl.espressif.com/dl/package_esp32_index.json`
3.  **Select Board:** `ESP32 Dev Module`
4.  **Connect ESP32 via USB**
5.  **Open `esp32_ble_led.ino`**
6.  **Upload** (Make sure to select the correct COM port)
7.  **Open Serial Monitor** (115200 baud) to verify: `✅ Vibro BLE Ready!`

## 📡 BLE Protocol

*   **Service UUID:** `6e400001-b5a3-f393-e0a9-e50e24dcca9e`
*   **Characteristic UUID:** `6e400002-b5a3-f393-e0a9-e50e24dcca9e` (Write Only)
*   **Command:** `0x01` (Blink LED for 2 seconds)

## 🔌 Wiring

*   **GPIO 2:** LED + Resistor (220Ω) → GND
*   **GND:** Common Ground

## 🧪 Testing

1.  Use `nRF Connect` app on mobile.
2.  Scan for `Vibro_Device`.
3.  Connect.
4.  Write `0x01` to the characteristic.
5.  LED should blink for 2 seconds.
