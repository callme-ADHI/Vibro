import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum BleStatus { disconnected, scanning, connecting, connected, unauthorized }

class BleService {
  BleService._();
  static final instance = BleService._();

  // ── Configuration ──
  static const String deviceName = "vibro";
  static const String serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  static const String characteristicUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";

  // ── State ──
  bool _isInitialized = false;
  BluetoothDevice? _targetDevice;
  BluetoothCharacteristic? _targetCharacteristic;
  
  final _statusController = StreamController<BleStatus>.broadcast();
  Stream<BleStatus> get statusStream => _statusController.stream;
  
  // For ListeningPage compatibility
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;
  
  BleStatus _currentStatus = BleStatus.disconnected;
  BleStatus get currentStatus => _currentStatus;
  bool get isConnected => _currentStatus == BleStatus.connected;

  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  Timer? _reconnectTimer;

  // ═══════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    
    print('DEBUG: BLE - Initializing...');
    _updateStatus(BleStatus.disconnected);
    
    // Set log level
    FlutterBluePlus.setLogLevel(LogLevel.none);

    // Listen to adapter state
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        startConnectionProcess();
      } else {
        _updateStatus(BleStatus.disconnected);
      }
    });
  }

  /// Request permissions and start the scan/connect loop
  Future<void> startConnectionProcess() async {
    // Force refresh
    _updateStatus(BleStatus.disconnected);
    await _targetDevice?.disconnect();
    _targetDevice = null;

    bool granted = await _requestPermissions();
    if (!granted) {
      _updateStatus(BleStatus.unauthorized);
      return;
    }

    _startScan();
  }

  /// Send a command byte to the device
  Future<bool> sendCommand(int commandByte) async {
    if (_targetCharacteristic == null) {
      print('DEBUG: BLE - Cannot send command, characteristic is NULL');
      return false;
    }

    try {
      print('DEBUG: BLE - Sending command: 0x${commandByte.toRadixString(16)}');
      await _targetCharacteristic!.write([commandByte], withoutResponse: false); // Changed to false for confirmation
      print('DEBUG: BLE - Command sent successfully!');
      return true;
    } catch (e) {
      print('DEBUG: BLE - Write failed: $e');
      return false;
    }
  }

  /// Convenience method for 2s blink
  Future<void> blinkLed() async {
    await sendCommand(0x01);
  }

  // ═══════════════════════════════════════════
  //  PRIVATE METHODS
  // ═══════════════════════════════════════════

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      return statuses.values.every((s) => s.isGranted);
    }
    // iOS handling is different but usually handled by Info.plist + package
    return true;
  }

  void _updateStatus(BleStatus status) {
    _currentStatus = status;
    _statusController.add(status);
    _connectionController.add(status == BleStatus.connected);
    print('DEBUG: BLE Status: $status');
  }

  void _startScan() async {
    if (_currentStatus == BleStatus.scanning) return;
    _updateStatus(BleStatus.scanning);

    // 1. Check already connected devices first (system-wide and app-wide)
    try {
      // Get all bonded/connected devices without strict UUID filtering first
      List<BluetoothDevice> systemDevices = await FlutterBluePlus.systemDevices([]);
      List<BluetoothDevice> connectedDevices = FlutterBluePlus.connectedDevices;
      
      List<BluetoothDevice> allPotentialDevices = [...systemDevices, ...connectedDevices];

      for (var device in allPotentialDevices) {
        String name = device.platformName.isNotEmpty ? device.platformName : device.advName;
        print('DEBUG: BLE - System Check: Found $name (${device.remoteId})');
        
        if (name.toLowerCase().contains(deviceName.toLowerCase())) {
          print('DEBUG: BLE - Found matched device in system: $name');
          _connectToDevice(device);
          return;
        }
      }
    } catch (e) {
      print('DEBUG: BLE - Error checking connected devices: $e');
    }

    // 2. Listen for scan results
    var subscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        String name = r.device.platformName.isEmpty ? r.advertisementData.localName : r.device.platformName;
        if (name.toLowerCase().contains(deviceName.toLowerCase())) {
          print('DEBUG: BLE - Found device via scan: $name');
          FlutterBluePlus.stopScan();
          _connectToDevice(r.device);
          break;
        }
      }
    });

    // 3. Start scanning
    try {
      // Use shorter timeout and no strict keywords for broader matching
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    } catch (e) {
      print('DEBUG: BLE - Scan error: $e');
    }

    // Wait for scan to finish then retry if needed
    Future.delayed(const Duration(seconds: 6), () {
      subscription.cancel();
      if (_currentStatus == BleStatus.scanning) {
        print('DEBUG: BLE - Scan timeout, retrying...');
        _updateStatus(BleStatus.disconnected);
        _scheduleReconnect();
      }
    });
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    _updateStatus(BleStatus.connecting);
    _targetDevice = device;

    // Listen for connection state changes
    _connectionSubscription?.cancel();
    _connectionSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _handleDisconnect();
      }
    });

    try {
      await device.connect(autoConnect: false);
      
      // Discover Services
      List<BluetoothService> services = await device.discoverServices();
      print('DEBUG: BLE - Discovered ${services.length} services');
      
      final targetServiceUuid = Guid(serviceUuid);
      final targetCharUuid = Guid(characteristicUuid);

      for (var s in services) {
        if (s.uuid == targetServiceUuid) {
          print('DEBUG: BLE - Found Target Service');
          for (var c in s.characteristics) {
            if (c.uuid == targetCharUuid) {
              print('DEBUG: BLE - Found Target Characteristic');
              _targetCharacteristic = c;
              _updateStatus(BleStatus.connected);
              _reconnectTimer?.cancel();
              return;
            }
          }
        }
      }
      
      print('DEBUG: BLE - Service/Characteristic not found');
      device.disconnect();
    } catch (e) {
      print('DEBUG: BLE - Connection error: $e');
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _targetCharacteristic = null;
    if (_currentStatus != BleStatus.disconnected) {
      _updateStatus(BleStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
        startConnectionProcess();
      }
    });
  }

  void dispose() {
    _connectionSubscription?.cancel();
    _reconnectTimer?.cancel();
    _statusController.close();
    _targetDevice?.disconnect();
  }
}
