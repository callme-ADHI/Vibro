// VIBRO — Phone-to-Phone BLE Service (Corrected Architecture)
// Uses bluetooth_low_energy 6.2.x
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │  ARCHITECTURE                                                            │
// │                                                                          │
// │  Connected Phone                           Deaf Phone                   │
// │  [PERIPHERAL / GATT SERVER]   ──────────►  [CENTRAL / GATT CLIENT]     │
// │   • Advertises "VIBRO-CONNECT"              • Scans & discovers nearby  │
// │   • Waits for Deaf phone to connect         • User picks device to pair │
// │   • On name detected → NOTIFY deaf          • Subscribes to notification│
// │     characteristic value                    • Receives → vibrate/alert  │
// │                                                                          │
// │  Alert Payload: "LABEL|NAME|0.92"                                        │
// └──────────────────────────────────────────────────────────────────────────┘
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:permission_handler/permission_handler.dart';

// ── UUIDs ──────────────────────────────────────────────────────────────────
final kVibroServiceUUID   = UUID.fromString('4a4b4c00-cafe-babe-c0ff-ee1234567890');
final kVibroAlertCharUUID = UUID.fromString('4a4b4c01-cafe-babe-c0ff-ee1234567890');
const kVibroDeviceLocalName = 'VIBRO-CONNECT';

// ── Alert payload ──────────────────────────────────────────────────────────
class PhoneAlertPayload {
  final String label;       // "DAD"      (alias deaf user gave to this person)
  final String name;        // "HARI"     (model name detected)
  final double confidence;  // 0.92

  const PhoneAlertPayload({
    required this.label,
    required this.name,
    required this.confidence,
  });

  Uint8List encode() =>
      Uint8List.fromList(utf8.encode('$label|$name|${confidence.toStringAsFixed(2)}'));

  static PhoneAlertPayload? decode(Uint8List bytes) {
    try {
      final parts = utf8.decode(bytes).split('|');
      if (parts.length < 3) return null;
      return PhoneAlertPayload(
        label: parts[0].trim(),
        name: parts[1].trim(),
        confidence: double.tryParse(parts[2].trim()) ?? 0.0,
      );
    } catch (_) {
      return null;
    }
  }
}

// ── Discovered device info (used in UI scan list) ─────────────────────────
class DiscoveredVibroDevice {
  final Peripheral peripheral;
  final String name;
  final int rssi; // signal strength

  const DiscoveredVibroDevice({
    required this.peripheral,
    required this.name,
    required this.rssi,
  });
}

// ── BLE Status ─────────────────────────────────────────────────────────────
enum PhoneBleStatus {
  idle,
  advertising,    // Connected phone: actively advertising
  scanning,       // Deaf phone: scanning for devices
  connecting,     // Deaf phone: connecting to a selected device
  paired,         // Both: GATT connection active
  disconnected,
  unsupported,
}

// ════════════════════════════════════════════════════════════════════════════
//  CONNECTED PHONE — GATT SERVER (Peripheral/Advertiser)
//  Advertises itself so Deaf phone can find and connect.
//  On name detection: notifies the connected Deaf phone via characteristic.
// ════════════════════════════════════════════════════════════════════════════
class ConnectedPhoneBleServer {
  ConnectedPhoneBleServer._();
  static final instance = ConnectedPhoneBleServer._();

  final PeripheralManager _pm = PeripheralManager();

  final _statusCtrl = StreamController<PhoneBleStatus>.broadcast();
  Stream<PhoneBleStatus> get statusStream => _statusCtrl.stream;

  PhoneBleStatus _status = PhoneBleStatus.idle;
  PhoneBleStatus get status => _status;
  bool get isAdvertising => _status == PhoneBleStatus.advertising;
  bool get isPaired    => _status == PhoneBleStatus.paired;

  // Track connected centrals (Deaf phones)
  final List<Central> _connectedCentrals = [];
  GATTCharacteristic? _alertChar;

  StreamSubscription? _connSub;
  StreamSubscription? _notifySub;

  // ── Start advertising ─────────────────────────────────────────────────────
  Future<void> startAdvertising() async {
    try {
      await [
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ].request();

      // Alert characteristic — NOTIFY so Deaf phone can subscribe
      _alertChar = GATTCharacteristic.mutable(
        uuid: kVibroAlertCharUUID,
        properties: [
          GATTCharacteristicProperty.notify,
          GATTCharacteristicProperty.read,
        ],
        permissions: [
          GATTCharacteristicPermission.read,
        ],
        descriptors: [],
      );

      final service = GATTService(
        uuid: kVibroServiceUUID,
        isPrimary: true,
        includedServices: [],
        characteristics: [_alertChar!],
      );

      await _pm.removeAllServices();
      await _pm.addService(service);

      // Track central (Deaf phone) connections
      _connSub?.cancel();
      _connSub = _pm.connectionStateChanged.listen((e) {
        if (e.state == ConnectionState.connected) {
          _connectedCentrals.add(e.central);
          _updateStatus(PhoneBleStatus.paired);
          print('VIBRO-SERVER: Deaf phone connected ✓');
        } else {
          _connectedCentrals.remove(e.central);
          _updateStatus(_connectedCentrals.isEmpty
              ? PhoneBleStatus.advertising
              : PhoneBleStatus.paired);
          print('VIBRO-SERVER: Deaf phone disconnected');
        }
      });

      // Track notify subscriptions from Deaf phone
      _notifySub?.cancel();
      _notifySub = _pm.characteristicNotifyStateChanged.listen((e) {
        print('VIBRO-SERVER: Notify state → ${e.state} for ${e.central.uuid.toString()}');
      });

      // Start advertising
      await _pm.startAdvertising(Advertisement(
        name: kVibroDeviceLocalName,
        serviceUUIDs: [kVibroServiceUUID],
      ));

      _updateStatus(PhoneBleStatus.advertising);
      print('VIBRO-SERVER: Advertising as "$kVibroDeviceLocalName" ✓');
    } catch (e) {
      print('VIBRO-SERVER: Failed: $e');
      _updateStatus(PhoneBleStatus.unsupported);
      rethrow;
    }
  }

  // ── Send alert to all connected Deaf phones ───────────────────────────────
  Future<bool> sendAlert(PhoneAlertPayload payload) async {
    if (_alertChar == null || _connectedCentrals.isEmpty) {
      print('VIBRO-SERVER: No Deaf phones connected');
      return false;
    }

    bool anySent = false;
    final bytes = payload.encode();

    for (final central in List.from(_connectedCentrals)) {
      try {
        await _pm.notifyCharacteristic(central, _alertChar!, value: bytes);
        print('VIBRO-SERVER: ✅ Alert sent to ${central.uuid.toString()} → ${utf8.decode(bytes)}');
        anySent = true;
      } catch (e) {
        print('VIBRO-SERVER: Notify failed for ${central.uuid.toString()}: $e');
      }
    }
    return anySent;
  }

  Future<void> stopAdvertising() async {
    _connSub?.cancel();
    _notifySub?.cancel();
    _connectedCentrals.clear();
    try { await _pm.stopAdvertising(); } catch (_) {}
    try { await _pm.removeAllServices(); } catch (_) {}
    _updateStatus(PhoneBleStatus.idle);
  }

  void _updateStatus(PhoneBleStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  void dispose() {
    stopAdvertising();
    _statusCtrl.close();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  DEAF PHONE — GATT CLIENT (Central/Scanner)
//  Scans for Connected phones, user picks one to pair.
//  Subscribes to alert characteristic → receives name detections.
// ════════════════════════════════════════════════════════════════════════════
class DeafPhoneBleClient {
  DeafPhoneBleClient._();
  static final instance = DeafPhoneBleClient._();

  final CentralManager _cm = CentralManager();

  // ── Status stream ──────────────────────────────────────────────────────────
  final _statusCtrl = StreamController<PhoneBleStatus>.broadcast();
  Stream<PhoneBleStatus> get statusStream => _statusCtrl.stream;

  // ── Discovered devices stream (for the scan page UI) ──────────────────────
  final _discoveredCtrl =
      StreamController<List<DiscoveredVibroDevice>>.broadcast();
  Stream<List<DiscoveredVibroDevice>> get discoveredStream =>
      _discoveredCtrl.stream;

  // ── Alert stream (incoming detections from Connected phone) ───────────────
  final _alertCtrl = StreamController<PhoneAlertPayload>.broadcast();
  Stream<PhoneAlertPayload> get alertStream => _alertCtrl.stream;

  PhoneBleStatus _status = PhoneBleStatus.idle;
  PhoneBleStatus get status => _status;
  bool get isPaired   => _status == PhoneBleStatus.paired;
  bool get isScanning => _status == PhoneBleStatus.scanning;

  // Track paired device info
  Peripheral? _pairedPeripheral;
  String _pairedDeviceName = '';
  String get pairedDeviceName => _pairedDeviceName;

  final Map<String, DiscoveredVibroDevice> _discovered = {};
  StreamSubscription? _discoverySub;
  StreamSubscription? _connSub;
  StreamSubscription? _notifySub;
  StreamSubscription? _stateSub;
  Timer? _scanStopTimer;

  // ── Start scanning ─────────────────────────────────────────────────────────
  Future<void> startScan() async {
    if (_status == PhoneBleStatus.scanning) return;

    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    _discovered.clear();
    _discoveredCtrl.add([]);
    _updateStatus(PhoneBleStatus.scanning);
    print('VIBRO-CLIENT: Starting scan for "$kVibroDeviceLocalName"...');

    _discoverySub?.cancel();
    _discoverySub = _cm.discovered.listen((e) {
      final name = e.advertisement.name ?? '';
      final hasService = e.advertisement.serviceUUIDs.any(
        (u) => u.toString().toLowerCase() == kVibroServiceUUID.toString().toLowerCase(),
      );

      if (name == kVibroDeviceLocalName || hasService) {
        final id = e.peripheral.uuid.toString();
        _discovered[id] = DiscoveredVibroDevice(
          peripheral: e.peripheral,
          name: name.isNotEmpty ? name : kVibroDeviceLocalName,
          rssi: e.rssi,
        );
        _discoveredCtrl.add(_discovered.values.toList());
        print('VIBRO-CLIENT: Found → $name (RSSI: ${e.rssi})');
      }
    });

    await _cm.startDiscovery(serviceUUIDs: [kVibroServiceUUID]).catchError((_) {
      _cm.startDiscovery().catchError((_) {});
    });

    // Auto-stop scan after 15s
    _scanStopTimer?.cancel();
    _scanStopTimer = Timer(const Duration(seconds: 15), stopScan);
  }

  // ── Stop scanning ──────────────────────────────────────────────────────────
  Future<void> stopScan() async {
    _discoverySub?.cancel();
    _scanStopTimer?.cancel();
    try { await _cm.stopDiscovery(); } catch (_) {}
    if (_status == PhoneBleStatus.scanning) {
      _updateStatus(PhoneBleStatus.idle);
    }
  }

  // ── Connect to a specific discovered device ────────────────────────────────
  Future<void> connectTo(DiscoveredVibroDevice device) async {
    await stopScan();
    _updateStatus(PhoneBleStatus.connecting);
    _pairedDeviceName = device.name;
    print('VIBRO-CLIENT: Connecting to ${device.name}...');

    // Track connection state
    _connSub?.cancel();
    _connSub = _cm.connectionStateChanged.listen((e) async {
      if (e.state == ConnectionState.connected &&
          e.peripheral.uuid == device.peripheral.uuid) {
        _pairedPeripheral = e.peripheral;
        _updateStatus(PhoneBleStatus.paired);
        await _subscribeToAlerts(e.peripheral);
        print('VIBRO-CLIENT: Paired ✓');
      } else if (e.state == ConnectionState.disconnected &&
          e.peripheral.uuid == device.peripheral.uuid) {
        _pairedPeripheral = null;
        _updateStatus(PhoneBleStatus.disconnected);
        print('VIBRO-CLIENT: Disconnected');
      }
    });

    try {
      await _cm.connect(device.peripheral);
    } catch (e) {
      print('VIBRO-CLIENT: connect() error: $e');
      _updateStatus(PhoneBleStatus.disconnected);
    }
  }

  // ── Subscribe to alert characteristic (NOTIFY) ────────────────────────────
  Future<void> _subscribeToAlerts(Peripheral peripheral) async {
    try {
      await _cm.requestMTU(peripheral, mtu: 247);
    } catch (_) {}

    try {
      final services = await _cm.discoverGATT(peripheral);
      GATTCharacteristic? alertChar;

      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() ==
            kVibroServiceUUID.toString().toLowerCase()) {
          for (final c in svc.characteristics) {
            if (c.uuid.toString().toLowerCase() ==
                kVibroAlertCharUUID.toString().toLowerCase()) {
              alertChar = c;
              break;
            }
          }
        }
      }

      if (alertChar == null) {
        print('VIBRO-CLIENT: Alert char not found');
        return;
      }

      // Enable NOTIFY
      await _cm.setCharacteristicNotifyState(
        peripheral,
        alertChar,
        state: true,
      );

      // Listen for notifications
      _notifySub?.cancel();
      _notifySub = _cm.characteristicNotified.listen((e) {
        if (e.peripheral.uuid == peripheral.uuid &&
            e.characteristic.uuid.toString().toLowerCase() ==
                kVibroAlertCharUUID.toString().toLowerCase()) {
          final payload = PhoneAlertPayload.decode(e.value);
          if (payload != null) {
            print('VIBRO-CLIENT: ✅ Alert received → ${utf8.decode(e.value)}');
            _alertCtrl.add(payload);
          }
        }
      });

      print('VIBRO-CLIENT: Subscribed to alerts ✓');
    } catch (e) {
      print('VIBRO-CLIENT: GATT discovery/subscribe error: $e');
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    _notifySub?.cancel();
    _connSub?.cancel();
    if (_pairedPeripheral != null) {
      try { await _cm.disconnect(_pairedPeripheral!); } catch (_) {}
    }
    _pairedPeripheral = null;
    _pairedDeviceName = '';
    _updateStatus(PhoneBleStatus.idle);
  }

  void _updateStatus(PhoneBleStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  void dispose() {
    disconnect();
    stopScan();
    _stateSub?.cancel();
    _statusCtrl.close();
    _discoveredCtrl.close();
    _alertCtrl.close();
  }
}
