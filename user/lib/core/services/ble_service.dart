import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  BleService._();
  static final BleService instance = BleService._();

  // ── CONFIG ──
  static const String _deviceName = "Vibro_Device";
  static const String _serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String _characteristicUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";

  // ── STATE ──
  BluetoothDevice? _device;
  BluetoothCharacteristic? _ledChar;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  Timer? _reconnectTimer;
  
  bool _isScanning = false;
  bool _isConnected = false;

  // ── PUBLIC GETTERS ──
  bool get isConnected => _isConnected;

  final StreamController<bool> _connectionStateController = StreamController.broadcast();
  Stream<bool> get connectionStream => _connectionStateController.stream;

  // ── INIT ──
  Future<void> initialize() async {
    print("BLE: Initializing...");
    
    // 1. Check Permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    if (statuses.values.any((s) => s.isDenied || s.isPermanentlyDenied)) {
      print("BLE: Permissions denied");
      return; // Can't proceed
    }

    // 2. Start Scan
    _startScan();
  }

  // ── SCANNING ──
  void _startScan() async {
    if (_isConnected || _isScanning) return;
    
    // Check if Bluetooth is ON
    if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
      print("BLE: Adapter is OFF");
      return;
    }

    print("BLE: Starting scan for $_deviceName...");
    _isScanning = true;

    // Listen to scan results
    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == _deviceName || r.advertisementData.localName == _deviceName) {
          print("BLE: Found $_deviceName!");
          _connectToDevice(r.device);
          break; // Stop loop
        }
      }
    });

    // Start scanning
    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      print("BLE: Scan Error: $e");
    }
    
    // Stop scanning flag after timeout
    Future.delayed(const Duration(seconds: 10), () {
        _isScanning = false;
        if (!_isConnected) {
            _scheduleReconnect();
        }
    });
  }

  // ── CONNECTION ──
  void _connectToDevice(BluetoothDevice device) async {
    // Stop scanning first
    FlutterBluePlus.stopScan();
    _scanSub?.cancel();
    _isScanning = false;

    if (_device != null && _device!.remoteId == device.remoteId && _isConnected) return;

    print("BLE: Connecting to ${device.remoteId}...");
    _device = device;

    try {
      await device.connect(autoConnect: false); // autoConnect is flaky on some Androids, handling manually
      _isConnected = true;
      _connectionStateController.add(true);
      print("BLE: Connected!");

      // Discover Services
      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        if (s.uuid.toString() == _serviceUuid) {
          for (var c in s.characteristics) {
            if (c.uuid.toString() == _characteristicUuid) {
              _ledChar = c;
              print("BLE: LED Characteristic Found!");
            }
          }
        }
      }

      // Listen to connection state
      _connSub?.cancel();
      _connSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          print("BLE: Disconnected");
          _isConnected = false;
          _connectionStateController.add(false);
          _ledChar = null;
          _scheduleReconnect();
        }
      });

    } catch (e) {
      print("BLE: Connection Failed: $e");
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  // ── RECONNECT LOGIC ──
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      print("BLE: Attempting Reconnect...");
      if (_device != null) {
          _connectToDevice(_device!);
      } else {
          _startScan();
      }
    });
  }

  // ── COMMANDS ──
  Future<void> blinkLed() async {
    if (!_isConnected || _ledChar == null) {
      print("BLE: Cannot blink - Not connected");
      return;
    }

    try {
      print("BLE: Sending BLINK Command [0x01]");
      // Write without response for speed
      await _ledChar!.write([0x01], withoutResponse: true);
    } catch (e) {
      print("BLE: Write Failed: $e");
    }
  }

  void dispose() {
    _scanSub?.cancel();
    _connSub?.cancel();
    _reconnectTimer?.cancel();
  }
}
