// VIBRO — WiFi Local P2P Service (Drop-in replacement for phone_ble_service.dart)
//
// ┌──────────────────────────────────────────────────────────────────────────────┐
// │  ARCHITECTURE                                                                │
// │                                                                              │
// │  Deaf Phone                                  Connected Phone                │
// │  [TCP SERVER / NSD Registrar]  ◄── WiFi ──  [TCP CLIENT / NSD Browser]     │
// │   • Registers _vibro._tcp mDNS               • Discovers via NSD            │
// │   • Listens on port 47476                    • User picks device            │
// │   • Accepts connections                      • Connects TCP socket           │
// │   • Receives alert JSON                      • On name detected → send JSON  │
// │   • Vibrates / notifies                      • Heartbeat keepalive (5s)     │
// │                                                                              │
// │  Protocol: newline-delimited JSON over TCP                                   │
// │  {"type":"alert","label":"DAD","name":"HARI","conf":0.92}                   │
// │  {"type":"ping"} / {"type":"pong"}                                           │
// └──────────────────────────────────────────────────────────────────────────────┘

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:network_info_plus/network_info_plus.dart';

// ── Constants ──────────────────────────────────────────────────────────────────
const int kVibroWifiPort = 47476;
const String kVibroServiceType = '_vibro._tcp';
const String kVibroServiceName = 'VIBRO-CONNECT';
const Duration kHeartbeatInterval = Duration(seconds: 5);
const Duration kConnectionTimeout = Duration(seconds: 10);
const Duration kReconnectDelay = Duration(seconds: 4);
const int kMaxReconnectAttempts = 20; // persist until user stops

// ── Platform channel to call Android NSD ──────────────────────────────────────
const MethodChannel _nsdChannel = MethodChannel('com.vibro.vibro/nsd');

// ── Alert payload (same as BLE version) ───────────────────────────────────────
class PhoneAlertPayload {
  final String label;
  final String name;
  final double confidence;

  const PhoneAlertPayload({
    required this.label,
    required this.name,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
        'type': 'alert',
        'label': label,
        'name': name,
        'conf': double.parse(confidence.toStringAsFixed(2)),
      };

  static PhoneAlertPayload? fromJson(Map<String, dynamic> json) {
    try {
      return PhoneAlertPayload(
        label: (json['label'] as String?) ?? 'Unknown',
        name: (json['name'] as String?) ?? '',
        confidence: (json['conf'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (_) {
      return null;
    }
  }

  // Legacy BLE encode/decode for compatibility
  List<int> encode() => utf8.encode('$label|$name|${confidence.toStringAsFixed(2)}');

  static PhoneAlertPayload? decode(List<int> bytes) {
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

// ── Discovered device (for scan list UI) ──────────────────────────────────────
class DiscoveredWifiDevice {
  final String id;         // unique: host:port
  final String name;
  final String host;
  final int port;
  final int rssi;          // synthetic: 0 for WiFi (not available)

  const DiscoveredWifiDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    this.rssi = 0,
  });
}

// Keep BLE name alias for UI compatibility
typedef DiscoveredVibroDevice = DiscoveredWifiDevice;

// ── WiFi Status (mirrors PhoneBleStatus exactly for UI drop-in) ───────────────
enum PhoneWifiStatus {
  idle,
  advertising,    // Deaf: server running, waiting for connection
  scanning,       // Connected: discovering via NSD
  connecting,     // Connected: TCP handshake in progress
  paired,         // Both: TCP connection active
  disconnected,
  unsupported,
}

// Alias so existing UI code that imports PhoneBleStatus still compiles
typedef PhoneBleStatus = PhoneWifiStatus;

// ════════════════════════════════════════════════════════════════════════════════
//  DEAF PHONE — TCP SERVER (NSD Registrar)
//  Deaf user holds power. Registers itself on local WiFi via mDNS.
//  Waits for Connected phone to connect. Receives alerts, vibrates.
// ════════════════════════════════════════════════════════════════════════════════
class DeafPhoneWifiServer {
  DeafPhoneWifiServer._();
  static final instance = DeafPhoneWifiServer._();

  // ── Streams ──────────────────────────────────────────────────────────────────
  final _statusCtrl = StreamController<PhoneWifiStatus>.broadcast();
  Stream<PhoneWifiStatus> get statusStream => _statusCtrl.stream;

  final _alertCtrl = StreamController<PhoneAlertPayload>.broadcast();
  Stream<PhoneAlertPayload> get alertStream => _alertCtrl.stream;

  PhoneWifiStatus _status = PhoneWifiStatus.idle;
  PhoneWifiStatus get status => _status;
  bool get isAdvertising => _status == PhoneWifiStatus.advertising;
  bool get isPaired => _status == PhoneWifiStatus.paired;

  // ── Internal state ────────────────────────────────────────────────────────
  RawDatagramSocket? _udpSocket;
  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  StreamSubscription? _socketSub;
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeout;
  bool _running = false;
  String _serverAddress = '';
  String get serverAddress => _serverAddress;

  final StringBuffer _readBuffer = StringBuffer();

  // ── Start server (Deaf phone calls this) ──────────────────────────────────
  Future<void> startServer() async {
    if (_running) return;
    _running = true;

    try {
      // 1. Bind TCP server socket
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, kVibroWifiPort)
          .timeout(const Duration(seconds: 5));

      // 2. Get our local IP for display
      _serverAddress = await _getLocalIp();

      // 3. Register mDNS service via platform channel
      await _registerNsd();

      // 4. Start UDP Discovery Listener (Reliable Hotspot/Local fallback)
      await _startUdpListener();

      _updateStatus(PhoneWifiStatus.advertising);
      print('VIBRO-SERVER: Listening on $_serverAddress:$kVibroWifiPort');

      // 4. Accept loop (non-blocking)
      _serverSocket!.listen(
        _onClientConnected,
        onError: (e) {
          print('VIBRO-SERVER: Accept error: $e');
          _scheduleRestart();
        },
        onDone: () {
          if (_running) _scheduleRestart();
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('VIBRO-SERVER: Start error: $e');
      _updateStatus(PhoneWifiStatus.unsupported);
      _running = false;
    }
  }

  void _onClientConnected(Socket client) {
    print('VIBRO-SERVER: Client connected from ${client.remoteAddress.address}');

    // Close existing connection if any
    _disconnectClient();

    _clientSocket = client;
    _updateStatus(PhoneWifiStatus.paired);
    _startHeartbeat();

    _readBuffer.clear();
    _socketSub = client
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen(
      (String chunk) => _onData(chunk),
      onError: (e) {
        print('VIBRO-SERVER: Socket error: $e');
        _handleClientDisconnect();
      },
      onDone: () {
        print('VIBRO-SERVER: Client disconnected');
        _handleClientDisconnect();
      },
      cancelOnError: false,
    );
  }

  void _onData(String chunk) {
    _readBuffer.write(chunk);
    final raw = _readBuffer.toString();
    final lines = raw.split('\n');

    // Process all complete lines (all but the last, which may be incomplete)
    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      _processMessage(line);
    }

    // Keep any incomplete line in buffer
    _readBuffer.clear();
    if (lines.isNotEmpty) {
      _readBuffer.write(lines.last);
    }
  }

  void _processMessage(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final type = json['type'] as String? ?? '';

      switch (type) {
        case 'hello':
          // Handshake — send welcome
          _send({'type': 'welcome'});
          break;
        case 'alert':
          final payload = PhoneAlertPayload.fromJson(json);
          if (payload != null) {
            print('VIBRO-SERVER: ✅ Alert: ${payload.label} → ${payload.name}');
            _alertCtrl.add(payload);
          }
          break;
        case 'ping':
          _send({'type': 'pong'});
          _resetHeartbeatTimeout();
          break;
        case 'pong':
          _resetHeartbeatTimeout();
          break;
        case 'bye':
          _handleClientDisconnect();
          break;
        default:
          break;
      }
    } catch (e) {
      print('VIBRO-SERVER: Message parse error: $e (line: $line)');
    }
  }

  void _send(Map<String, dynamic> json) {
    try {
      _clientSocket?.write('${jsonEncode(json)}\n');
    } catch (e) {
      print('VIBRO-SERVER: Send error: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimeout?.cancel();

    _heartbeatTimer = Timer.periodic(kHeartbeatInterval, (_) {
      _send({'type': 'ping'});
    });

    _resetHeartbeatTimeout();
  }

  void _resetHeartbeatTimeout() {
    _heartbeatTimeout?.cancel();
    // If no pong in 15s, consider disconnected
    _heartbeatTimeout = Timer(const Duration(seconds: 15), () {
      print('VIBRO-SERVER: Heartbeat timeout');
      _handleClientDisconnect();
    });
  }

  void _handleClientDisconnect() {
    _disconnectClient();
    if (_running) {
      _updateStatus(PhoneWifiStatus.advertising);
    }
  }

  void _disconnectClient() {
    _heartbeatTimer?.cancel();
    _heartbeatTimeout?.cancel();
    _socketSub?.cancel();
    try { _clientSocket?.destroy(); } catch (_) {}
    _clientSocket = null;
    _readBuffer.clear();
  }

  Future<void> _scheduleRestart() async {
    if (!_running) return;
    await Future.delayed(kReconnectDelay);
    if (_running) {
      await _restartServer();
    }
  }

  Future<void> _restartServer() async {
    try { _serverSocket?.close(); } catch (_) {}
    _serverSocket = null;
    _updateStatus(PhoneWifiStatus.disconnected);
    await Future.delayed(const Duration(seconds: 2));
    if (_running) await startServer();
  }

  Future<String> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        // Prefer wlan0 or similar
        if (iface.name.toLowerCase().contains('wlan') ||
            iface.name.toLowerCase().contains('wifi') ||
            iface.name.toLowerCase().contains('en')) {
          if (iface.addresses.isNotEmpty) {
            return iface.addresses.first.address;
          }
        }
      }
      // Fallback: any non-loopback
      for (final iface in interfaces) {
        if (iface.addresses.isNotEmpty) {
          return iface.addresses.first.address;
        }
      }
    } catch (_) {}
    return '?.?.?.?';
  }

  Future<void> _registerNsd() async {
    try {
      await _nsdChannel.invokeMethod('registerService', {
        'serviceType': kVibroServiceType,
        'serviceName': kVibroServiceName,
        'port': kVibroWifiPort,
      });
    } catch (e) {
      print('VIBRO-SERVER: NSD register error (non-fatal): $e');
      // NSD failure is non-fatal — manual IP entry still works
    }
  }

  Future<void> _unregisterNsd() async {
    try {
      await _nsdChannel.invokeMethod('unregisterService');
    } catch (_) {}
  }

  // ── UDP Discovery Listener ───────────────────────────────────────────────
  Future<void> _startUdpListener() async {
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 47477);
      _udpSocket?.broadcastEnabled = true;
      _udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket?.receive();
          if (datagram != null) {
            try {
              final msg = utf8.decode(datagram.data);
              if (msg.contains('"ping"')) {
                // Reply directly to sender with our TCP endpoint details
                final reply = jsonEncode({
                  'type': 'pong',
                  'name': kVibroServiceName,
                  'port': kVibroWifiPort
                });
                _udpSocket?.send(utf8.encode(reply), datagram.address, datagram.port);
              }
            } catch (_) {}
          }
        }
      });
      print('VIBRO-SERVER: UDP Discovery active on port 47477');
    } catch (e) {
      print('VIBRO-SERVER: UDP bind error (ignored): $e');
    }
  }

  // ── Stop server ──────────────────────────────────────────────────────────
  Future<void> stopServer() async {
    _running = false;
    _disconnectClient();
    await _unregisterNsd();
    _udpSocket?.close();
    _udpSocket = null;
    try { _serverSocket?.close(); } catch (_) {}
    _serverSocket = null;
    _updateStatus(PhoneWifiStatus.idle);
    print('VIBRO-SERVER: Stopped');
  }

  void _updateStatus(PhoneWifiStatus s) {
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  void dispose() {
    stopServer();
    _statusCtrl.close();
    _alertCtrl.close();
  }
}

// Legacy alias — so existing code importing ConnectedPhoneBleServer still compiles
typedef ConnectedPhoneBleServer = ConnectedPhoneWifiClient;

// ════════════════════════════════════════════════════════════════════════════════
//  CONNECTED PHONE — TCP CLIENT (NSD Browser)
//  Scans local network via NSD/mDNS for Deaf phone's server.
//  User picks device → TCP connect → send JSON alerts on name detection.
// ════════════════════════════════════════════════════════════════════════════════
class ConnectedPhoneWifiClient {
  ConnectedPhoneWifiClient._();
  static final instance = ConnectedPhoneWifiClient._();

  // ── Streams ──────────────────────────────────────────────────────────────────
  final _statusCtrl = StreamController<PhoneWifiStatus>.broadcast();
  Stream<PhoneWifiStatus> get statusStream => _statusCtrl.stream;

  final _discoveredCtrl =
      StreamController<List<DiscoveredWifiDevice>>.broadcast();
  Stream<List<DiscoveredWifiDevice>> get discoveredStream =>
      _discoveredCtrl.stream;

  PhoneWifiStatus _status = PhoneWifiStatus.idle;
  PhoneWifiStatus get status => _status;
  bool get isPaired => _status == PhoneWifiStatus.paired;
  bool get isScanning => _status == PhoneWifiStatus.scanning;
  bool get isAdvertising => _status == PhoneWifiStatus.advertising;

  String _pairedDeviceName = '';
  String get pairedDeviceName => _pairedDeviceName;

  // ── Internal state ────────────────────────────────────────────────────────
  Socket? _socket;
  StreamSubscription? _socketSub;
  Timer? _heartbeatTimer;
  Timer? _heartbeatTimeout;
  Timer? _scanTimeout;
  bool _connected = false;
  int _reconnectAttempts = 0;
  DiscoveredWifiDevice? _currentDevice;

  final Map<String, DiscoveredWifiDevice> _discovered = {};
  final StringBuffer _readBuffer = StringBuffer();
  RawDatagramSocket? _udpSocket;
  Timer? _udpTimer;
  bool _autoConnectEnabled = false;

  // ── NSD event channel ──────────────────────────────────────────────────────
  static const EventChannel _nsdEvents = EventChannel('com.vibro.vibro/nsd_events');
  StreamSubscription? _nsdEventSub;

  // ── Start scanning (Connected phone) ──────────────────────────────────────
  Future<void> startAutoConnect() async {
    _autoConnectEnabled = true;
    await startScan();
  }

  Future<void> startScan() async {
    if (_status == PhoneWifiStatus.scanning) return;

    _discovered.clear();
    _discoveredCtrl.add([]);
    _updateStatus(PhoneWifiStatus.scanning);
    print('VIBRO-CLIENT: Starting NSD discovery...');

    // Listen for NSD events from Android
    _nsdEventSub?.cancel();
    _nsdEventSub = _nsdEvents.receiveBroadcastStream().listen(
      _onNsdEvent,
      onError: (e) {
        print('VIBRO-CLIENT: NSD event error: $e');
      },
    );

    // Start discovery
    try {
      await _nsdChannel.invokeMethod('startDiscovery', {
        'serviceType': kVibroServiceType,
      });
    } catch (e) {
      print('VIBRO-CLIENT: NSD start error: $e');
    }

    // Hotspot Fallback: if the Deaf phone is hosting a portable AP, 
    // Android completely suppresses mDNS packets. BUT the Deaf phone's IP 
    // is exactly the WiFi Gateway IP. So we add it immediately:
    try {
      final gatewayIp = await NetworkInfo().getWifiGatewayIP();
      if (gatewayIp != null && gatewayIp.isNotEmpty && gatewayIp != '0.0.0.0') {
        final gwId = '$gatewayIp:$kVibroWifiPort';
        
        // Let's test if the socket is actually open on the gateway before showing it
        // Do it without blocking the scan flow
        Socket.connect(gatewayIp, kVibroWifiPort, timeout: const Duration(seconds: 2))
          .then((socket) {
            socket.destroy();
            print('VIBRO-CLIENT: Hotspot gateway found ($gatewayIp)');
            _addDevice(DiscoveredWifiDevice(
              id: gwId,
              name: 'VIBRO-CONNECT (Hotspot)',
              host: gatewayIp,
              port: kVibroWifiPort,
              rssi: -30, // Excellent signal (it's the AP itself)
            ));
          }).catchError((_) {
            // It's a gateway but there's no server running on port 47476
          });
      }
    } catch (_) {}

    // Reliable Fallback 2: UDP Broadcast (bypasses Android mDNS suppression)
    await _startUdpScanner();

    // Auto-stop after 30s
    _scanTimeout?.cancel();
    _scanTimeout = Timer(const Duration(seconds: 30), stopScan);
  }

  Future<void> _startUdpScanner() async {
    try {
      _udpSocket?.close();
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket?.broadcastEnabled = true;
      _udpSocket?.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final dg = _udpSocket?.receive();
          if (dg != null) {
            try {
              final msg = utf8.decode(dg.data);
              final json = jsonDecode(msg);
              if (json['type'] == 'pong') {
                final host = dg.address.address;
                final port = json['port'] ?? kVibroWifiPort;
                final name = json['name'] ?? 'VIBRO-CONNECT (UDP)';
                final id = '$host:$port';
                print('VIBRO-CLIENT: UDP proxy found → $host:$port');
                _addDevice(DiscoveredWifiDevice(
                  id: id,
                  name: name,
                  host: host,
                  port: port,
                  rssi: -50,
                ));
              }
            } catch (_) {}
          }
        }
      });

      // Blast UDP pings every 2s
      _udpTimer?.cancel();
      _udpTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_status == PhoneWifiStatus.scanning) {
          try {
            final payload = utf8.encode(jsonEncode({'type': 'ping'}));
            _udpSocket?.send(payload, InternetAddress('255.255.255.255'), 47477);
          } catch (_) {}
        } else {
          _udpTimer?.cancel();
        }
      });
    } catch (e) {
      print('VIBRO-CLIENT: UDP scan error (ignored): $e');
    }
  }

  void _onNsdEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['event'] as String? ?? '';
    
    if (type == 'found') {
      final name = event['name'] as String? ?? kVibroServiceName;
      final host = event['host'] as String? ?? '';
      final port = (event['port'] as int?) ?? kVibroWifiPort;
      
      if (host.isEmpty) return;
      print('VIBRO-CLIENT: Found → $name @ $host:$port');
      _addDevice(DiscoveredWifiDevice(
        id: '$host:$port',
        name: name,
        host: host,
        port: port,
        rssi: 0,
      ));
    } else if (type == 'lost') {
      final host = event['host'] as String? ?? '';
      final port = (event['port'] as int?) ?? kVibroWifiPort;
      _discovered.remove('$host:$port');
      _discoveredCtrl.add(_discovered.values.toList());
    }
  }

  // ── Stop scanning ──────────────────────────────────────────────────────────
  Future<void> stopScan() async {
    _nsdEventSub?.cancel();
    _scanTimeout?.cancel();
    _udpTimer?.cancel();
    _udpSocket?.close();
    _udpSocket = null;
    try {
      await _nsdChannel.invokeMethod('stopDiscovery');
    } catch (_) {}
    if (_status == PhoneWifiStatus.scanning) {
      _updateStatus(PhoneWifiStatus.idle);
    }
  }

  void _addDevice(DiscoveredWifiDevice device) {
    if (_discovered.containsKey(device.id)) return;

    _discovered[device.id] = device;
    _discoveredCtrl.add(_discovered.values.toList());

    if (_autoConnectEnabled && !isPaired && _status != PhoneWifiStatus.connecting) {
      print('VIBRO-CLIENT: Auto-connecting seamlessly to: ${device.id}');
      connectTo(device);
    }
  }

  // ── Connect to selected device ─────────────────────────────────────────────
  Future<void> connectTo(DiscoveredWifiDevice device) async {
    await stopScan();
    _currentDevice = device;
    _pairedDeviceName = device.name;
    _reconnectAttempts = 0;
    await _doConnect(device);
  }

  Future<void> _doConnect(DiscoveredWifiDevice device) async {
    _updateStatus(PhoneWifiStatus.connecting);
    print('VIBRO-CLIENT: Connecting to ${device.host}:${device.port}');

    try {
      _socket = await Socket.connect(device.host, device.port,
          timeout: kConnectionTimeout);

      _connected = true;
      _reconnectAttempts = 0;
      _updateStatus(PhoneWifiStatus.paired);
      print('VIBRO-CLIENT: Connected ✓');

      // Send handshake
      _send({'type': 'hello', 'name': kVibroServiceName});

      // Start heartbeat
      _startHeartbeat();

      // Listen for responses
      _readBuffer.clear();
      _socketSub = _socket!
          .cast<List<int>>()
          .transform(utf8.decoder)
          .listen(
        (String chunk) => _onData(chunk),
        onError: (e) {
          print('VIBRO-CLIENT: Socket error: $e');
          _handleDisconnect();
        },
        onDone: () {
          print('VIBRO-CLIENT: Connection closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('VIBRO-CLIENT: Connection error: $e');
      _scheduleReconnect();
    }
  }

  void _onData(String chunk) {
    _readBuffer.write(chunk);
    final raw = _readBuffer.toString();
    final lines = raw.split('\n');

    for (int i = 0; i < lines.length - 1; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      _processMessage(line);
    }

    _readBuffer.clear();
    if (lines.isNotEmpty) {
      _readBuffer.write(lines.last);
    }
  }

  void _processMessage(String line) {
    try {
      final json = jsonDecode(line) as Map<String, dynamic>;
      final type = json['type'] as String? ?? '';
      switch (type) {
        case 'welcome':
          print('VIBRO-CLIENT: Handshake complete ✓');
          break;
        case 'ping':
          _send({'type': 'pong'});
          _resetHeartbeatTimeout();
          break;
        case 'pong':
          _resetHeartbeatTimeout();
          break;
        case 'bye':
          _handleDisconnect();
          break;
        default:
          break;
      }
    } catch (e) {
      print('VIBRO-CLIENT: Message parse error: $e');
    }
  }

  // ── Send alert to Deaf phone ───────────────────────────────────────────────
  Future<bool> sendAlert(PhoneAlertPayload payload) async {
    if (!_connected || _socket == null) {
      print('VIBRO-CLIENT: Not connected, cannot send alert');
      return false;
    }
    try {
      _send(payload.toJson());
      print('VIBRO-CLIENT: ✅ Alert sent: ${payload.label} → ${payload.name}');
      return true;
    } catch (e) {
      print('VIBRO-CLIENT: Alert send error: $e');
      _handleDisconnect();
      return false;
    }
  }

  void _send(Map<String, dynamic> json) {
    try {
      _socket?.write('${jsonEncode(json)}\n');
    } catch (e) {
      print('VIBRO-CLIENT: Send error: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(kHeartbeatInterval, (_) {
      if (_connected) _send({'type': 'ping'});
    });
    _resetHeartbeatTimeout();
  }

  void _resetHeartbeatTimeout() {
    _heartbeatTimeout?.cancel();
    _heartbeatTimeout = Timer(const Duration(seconds: 15), () {
      print('VIBRO-CLIENT: Heartbeat timeout');
      _handleDisconnect();
    });
  }

  void _handleDisconnect() {
    _connected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimeout?.cancel();
    _socketSub?.cancel();
    try { _socket?.destroy(); } catch (_) {}
    _socket = null;
    _readBuffer.clear();

    if (_status != PhoneWifiStatus.idle) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= kMaxReconnectAttempts || _currentDevice == null) {
      _updateStatus(PhoneWifiStatus.disconnected);
      return;
    }
    _reconnectAttempts++;
    _updateStatus(PhoneWifiStatus.connecting);
    
    final delay = Duration(seconds: min(kReconnectDelay.inSeconds * _reconnectAttempts, 30));
    print('VIBRO-CLIENT: Reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    
    Timer(delay, () {
      if (_currentDevice != null && _status != PhoneWifiStatus.paired && _status != PhoneWifiStatus.idle) {
        _doConnect(_currentDevice!);
      }
    });
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    _currentDevice = null;
    _pairedDeviceName = '';
    _reconnectAttempts = kMaxReconnectAttempts; // Prevent auto-reconnect
    _send({'type': 'bye'});
    _connected = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimeout?.cancel();
    _socketSub?.cancel();
    try { _socket?.destroy(); } catch (_) {}
    _socket = null;
    _updateStatus(PhoneWifiStatus.idle);
  }

  // Alias for BLE compatibility
  Future<void> startAdvertising() => Future.value(); // No-op for client
  Future<void> stopAdvertising() => disconnect();

  void _updateStatus(PhoneWifiStatus s) {
    _status = s;
    if (!_statusCtrl.isClosed) _statusCtrl.add(s);
  }

  void dispose() {
    disconnect();
    stopScan();
    _statusCtrl.close();
    _discoveredCtrl.close();
  }
}

// ── Legacy aliases for pages that import DeafPhoneBleClient ──────────────────
typedef DeafPhoneBleClient = DeafPhoneWifiServer;

// Extension so existing UI code calling _client.connectTo(device) still works
extension DeafWifiServerConnectAlias on DeafPhoneWifiServer {
  // Deaf phone doesn't connect — it starts server. But the BLE page calls
  // these — they're no-ops on server side.
  Future<void> startScan() => startServer();
  Future<void> stopScan() => Future.value();
  Stream<List<DiscoveredWifiDevice>> get discoveredStream =>
      Stream.value([]);
  Stream<PhoneAlertPayload> get alertStream => _alertCtrl.stream;
  bool get isScanning => false;
  bool get isPaired => status == PhoneWifiStatus.paired;
  String get pairedDeviceName => serverAddress;
}
