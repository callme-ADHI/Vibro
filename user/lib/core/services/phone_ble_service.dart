// VIBRO — Phone-to-Phone BLE Service
// Uses bluetooth_low_energy 6.2.x (supports Central + Peripheral roles).
//
// ┌───────────────────────────────────────────────────────────────────────┐
// │  ARCHITECTURE                                                         │
// │                                                                       │
// │  Deaf Phone          BLE GATT            Connected Phone              │
// │  [Peripheral]  ◄── write alert ──────── [Central]                    │
// │  [GATT Server]     "DAD|HARI|0.92"      [GATT Client]                │
// │                                                                       │
// │  Flow:                                                                │
// │   1. Deaf phone advertises VIBRO-DEAF service UUID                   │
// │   2. Connected phone scans → find → connect → discover               │
// │   3. On name detected: Connected writes "LABEL|NAME|CONF"            │
// │   4. Deaf phone: characteristicWriteRequested fires → alert          │
// └───────────────────────────────────────────────────────────────────────┘
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';

// ── UUIDs ──────────────────────────────────────────────────────────────────
final _kServiceUUID   = UUID.fromString('4a4b4c00-cafe-babe-deaf-c0ffee123456');
final _kAlertCharUUID = UUID.fromString('4a4b4c01-cafe-babe-deaf-c0ffee123456');
const kVibroDeviceLocalName = 'VIBRO-DEAF';

// ── Payload ────────────────────────────────────────────────────────────────
class PhoneAlertPayload {
  final String label;        // "DAD"
  final String name;         // "HARI"
  final double confidence;   // 0.92

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

// ── Status ─────────────────────────────────────────────────────────────────
enum PhoneBleStatus {
  idle,
  advertising,    // Deaf: GATT server active, no central connected
  scanning,       // Connected: searching for Deaf phone
  connecting,     // Connected: GATT connect in progress
  paired,         // Active GATT connection
  disconnected,
  unsupported,
}

// ═══════════════════════════════════════════════════════════════════════════
//  DEAF PHONE — GATT SERVER (Peripheral)
// ═══════════════════════════════════════════════════════════════════════════
class DeafPhoneBleServer {
  DeafPhoneBleServer._();
  static final instance = DeafPhoneBleServer._();

  final PeripheralManager _pm = PeripheralManager();

  final _statusCtrl = StreamController<PhoneBleStatus>.broadcast();
  Stream<PhoneBleStatus> get statusStream => _statusCtrl.stream;

  final _alertCtrl = StreamController<PhoneAlertPayload>.broadcast();
  Stream<PhoneAlertPayload> get alertStream => _alertCtrl.stream;

  PhoneBleStatus _status = PhoneBleStatus.idle;
  PhoneBleStatus get status => _status;
  bool get isPaired => _status == PhoneBleStatus.paired;

  GATTCharacteristic? _alertChar;
  StreamSubscription? _writeSub;
  StreamSubscription? _connSub;

  // ── Start advertising ─────────────────────────────────────────────────────
  Future<void> startAdvertising() async {
    try {
      // Build mutable alert characteristic — write + notify
      _alertChar = GATTCharacteristic.mutable(
        uuid: _kAlertCharUUID,
        properties: [
          GATTCharacteristicProperty.write,
          GATTCharacteristicProperty.writeWithoutResponse,
          GATTCharacteristicProperty.notify,
        ],
        permissions: [
          GATTCharacteristicPermission.write,
          GATTCharacteristicPermission.writeEncrypted, // write (encrypted version also works)
        ],
        descriptors: [],
      );

      // Service
      final service = GATTService(
        uuid: _kServiceUUID,
        isPrimary: true,
        includedServices: [],
        characteristics: [_alertChar!],
      );

      await _pm.removeAllServices();
      await _pm.addService(service);

      // Listen for writes from the Connected phone
      _writeSub?.cancel();
      _writeSub = _pm.characteristicWriteRequested.listen((e) async {
        if (e.characteristic.uuid == _kAlertCharUUID) {
          final bytes = e.request.value;
          // Respond with OK
          try { await _pm.respondWriteRequest(e.request); } catch (_) {}
          // Decode and forward
          final payload = PhoneAlertPayload.decode(bytes);
          if (payload != null) {
            print('VIBRO-BLE-SERVER: ✅ Alert received: ${utf8.decode(bytes)}');
            _alertCtrl.add(payload);
          }
        }
      });

      // Track central connect/disconnect
      _connSub?.cancel();
      _connSub = _pm.connectionStateChanged.listen((e) {
        final s = e.state == ConnectionState.connected
            ? PhoneBleStatus.paired
            : PhoneBleStatus.advertising;
        _updateStatus(s);
        print('VIBRO-BLE-SERVER: Central ${e.state.name}');
      });

      // Start advertising
      await _pm.startAdvertising(Advertisement(
        name: kVibroDeviceLocalName,
        serviceUUIDs: [_kServiceUUID],
      ));

      _updateStatus(PhoneBleStatus.advertising);
      print('VIBRO-BLE-SERVER: Advertising as "$kVibroDeviceLocalName" ✓');
    } catch (e) {
      print('VIBRO-BLE-SERVER: Failed: $e');
      _updateStatus(PhoneBleStatus.unsupported);
    }
  }

  Future<void> stopAdvertising() async {
    _writeSub?.cancel();
    _connSub?.cancel();
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
    _alertCtrl.close();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CONNECTED PHONE — GATT CLIENT (Central)
// ═══════════════════════════════════════════════════════════════════════════
class ConnectedPhoneBleClient {
  ConnectedPhoneBleClient._();
  static final instance = ConnectedPhoneBleClient._();

  final CentralManager _cm = CentralManager();

  final _statusCtrl = StreamController<PhoneBleStatus>.broadcast();
  Stream<PhoneBleStatus> get statusStream => _statusCtrl.stream;

  PhoneBleStatus _status = PhoneBleStatus.idle;
  PhoneBleStatus get status => _status;
  bool get isPaired => _status == PhoneBleStatus.paired;

  Peripheral? _deafPhone;
  GATTCharacteristic? _alertChar;

  StreamSubscription? _discoverySub;
  StreamSubscription? _connSub;
  StreamSubscription? _stateSub;
  Timer? _retryTimer;
  bool _shouldConnect = false;

  // ── Start scanning for the Deaf phone ─────────────────────────────────────
  Future<void> startScanning() async {
    if (_status == PhoneBleStatus.scanning || _status == PhoneBleStatus.paired) return;
    _shouldConnect = true;

    // React to BT adapter changes
    _stateSub ??= _cm.stateChanged.listen((e) {
      if (e.state == BluetoothLowEnergyState.poweredOn && _shouldConnect) {
        _doScan();
      }
    });

    // Connection state changes
    _connSub?.cancel();
    _connSub = _cm.connectionStateChanged.listen((e) async {
      if (e.state == ConnectionState.connected) {
        _updateStatus(PhoneBleStatus.paired);
        await _discoverAlertChar(e.peripheral);
      } else if (e.state == ConnectionState.disconnected) {
        _alertChar = null;
        _updateStatus(PhoneBleStatus.disconnected);
        if (_shouldConnect) {
          _retryTimer = Timer(const Duration(seconds: 3), _doScan);
        }
      }
    });

    _doScan();
  }

  void _doScan() {
    if (!_shouldConnect) return;
    _updateStatus(PhoneBleStatus.scanning);
    print('VIBRO-BLE-CLIENT: Scanning for "$kVibroDeviceLocalName"...');

    _discoverySub?.cancel();
    _discoverySub = _cm.discovered.listen((e) async {
      final name = e.advertisement.name ?? '';
      final hasVibro = name == kVibroDeviceLocalName ||
          e.advertisement.serviceUUIDs.any(
            (u) => u.toString().toLowerCase() == _kServiceUUID.toString().toLowerCase(),
          );

      if (hasVibro) {
        print('VIBRO-BLE-CLIENT: Deaf phone found → ${e.peripheral.uuid}');
        await _cm.stopDiscovery();
        _discoverySub?.cancel();
        _deafPhone = e.peripheral;
        _updateStatus(PhoneBleStatus.connecting);
        try {
          await _cm.connect(e.peripheral);
        } catch (err) {
          print('VIBRO-BLE-CLIENT: connect() error: $err');
          _alertChar = null;
          _updateStatus(PhoneBleStatus.disconnected);
          if (_shouldConnect) {
            _retryTimer = Timer(const Duration(seconds: 4), _doScan);
          }
        }
      }
    });

    _cm.startDiscovery(serviceUUIDs: [_kServiceUUID]).catchError((_) {
      // Wider scan if service-filtered fails
      _cm.startDiscovery().catchError((_) {});
    });

    // Auto-retry scan after 12s if still not found
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 12), () {
      if (_status == PhoneBleStatus.scanning && _shouldConnect) {
        _cm.stopDiscovery().ignore();
        _doScan();
      }
    });
  }

  // ── Discover alert characteristic ─────────────────────────────────────────
  Future<void> _discoverAlertChar(Peripheral peripheral) async {
    try {
      await _cm.requestMTU(peripheral, mtu: 247);
    } catch (_) {}

    try {
      final services = await _cm.discoverGATT(peripheral);
      for (final svc in services) {
        if (svc.uuid.toString().toLowerCase() ==
            _kServiceUUID.toString().toLowerCase()) {
          for (final c in svc.characteristics) {
            if (c.uuid.toString().toLowerCase() ==
                _kAlertCharUUID.toString().toLowerCase()) {
              _alertChar = c;
              print('VIBRO-BLE-CLIENT: Alert characteristic found ✓');
              return;
            }
          }
        }
      }
      print('VIBRO-BLE-CLIENT: ⚠️ Alert characteristic not found');
    } catch (e) {
      print('VIBRO-BLE-CLIENT: GATT discovery error: $e');
    }
  }

  // ── Send alert to Deaf phone ───────────────────────────────────────────────
  Future<bool> sendAlert(PhoneAlertPayload payload) async {
    final phone = _deafPhone;
    final char = _alertChar;
    if (phone == null || char == null || _status != PhoneBleStatus.paired) {
      print('VIBRO-BLE-CLIENT: Not paired — cannot send alert');
      return false;
    }
    try {
      await _cm.writeCharacteristic(
        phone,
        char,
        value: payload.encode(),
        type: GATTCharacteristicWriteType.withResponse,
      );
      print('VIBRO-BLE-CLIENT: ✅ Alert sent → ${utf8.decode(payload.encode())}');
      return true;
    } catch (e) {
      print('VIBRO-BLE-CLIENT: Write failed: $e');
      return false;
    }
  }

  // ── Stop ──────────────────────────────────────────────────────────────────
  Future<void> stopScanning() async {
    _shouldConnect = false;
    _retryTimer?.cancel();
    _discoverySub?.cancel();
    try { await _cm.stopDiscovery(); } catch (_) {}
    if (_deafPhone != null) {
      try { await _cm.disconnect(_deafPhone!); } catch (_) {}
    }
    _alertChar = null;
    _deafPhone = null;
    _updateStatus(PhoneBleStatus.idle);
  }

  void _updateStatus(PhoneBleStatus s) {
    _status = s;
    _statusCtrl.add(s);
  }

  void dispose() {
    stopScanning();
    _stateSub?.cancel();
    _statusCtrl.close();
  }
}
