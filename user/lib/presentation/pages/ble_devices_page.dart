// VIBRO — BLE Devices Page (Deaf User)
// Scan for nearby Connected phones, select one and pair.
// Once paired, name-detection alerts arrive via Bluetooth instantly.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/phone_ble_service.dart';
import '../../core/services/ble_service.dart';

class BleDevicesPage extends StatefulWidget {
  const BleDevicesPage({super.key});

  @override
  State<BleDevicesPage> createState() => _BleDevicesPageState();
}

class _BleDevicesPageState extends State<BleDevicesPage>
    with SingleTickerProviderStateMixin {
  final DeafPhoneBleClient _client = DeafPhoneBleClient.instance;
  final BleService _esp32 = BleService.instance;

  PhoneBleStatus _status = PhoneBleStatus.idle;
  List<DiscoveredVibroDevice> _devices = [];
  String? _connectingId;

  StreamSubscription<PhoneBleStatus>? _statusSub;
  StreamSubscription<List<DiscoveredVibroDevice>>? _devicesSub;
  StreamSubscription<PhoneAlertPayload>? _alertSub;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Pulse animation for scanning
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initNotifications();

    _status = _client.status;
    _statusSub = _client.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
      if (s == PhoneBleStatus.scanning) {
        _pulseCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      }
      if (s == PhoneBleStatus.paired) {
        _connectingId = null;
        _showSnack('Paired! You will now receive alerts via Bluetooth.', success: true);
      }
    });

    _devicesSub = _client.discoveredStream.listen((devices) {
      if (!mounted) return;
      setState(() => _devices = devices);
    });

    // When already paired, still listen for incoming alerts
    _alertSub = _client.alertStream.listen(_onAlertReceived);
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: android));
    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Alert received via BLE ────────────────────────────────────────────────
  Future<void> _onAlertReceived(PhoneAlertPayload payload) async {
    // Double-pulse vibration
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]);
    } else {
      HapticFeedback.heavyImpact();
    }

    // Flash ESP32 LED if connected
    if (_esp32.isConnected) _esp32.blinkLed();

    // System notification
    await _notifications.show(
      99,
      '📣 ${payload.label} called you!',
      '"${payload.name}" · ${(payload.confidence * 100).toInt()}% confidence · via Bluetooth',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'vibro_ble_alerts',
          'Bluetooth Alerts',
          channelDescription: 'Real-time alerts from Connected users via BLE',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );

    // In-app snack
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.primaryNavy,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Row(children: [
          const Icon(Icons.bluetooth_rounded, color: AppColors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${payload.label} called you! ("${payload.name}" - ${(payload.confidence * 100).toInt()}%)',
              style: AppTypography.bodyMedium(color: AppColors.white),
            ),
          ),
        ]),
      ));
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _startScan() => _client.startScan();
  void _stopScan() => _client.stopScan();

  Future<void> _connectTo(DiscoveredVibroDevice device) async {
    setState(() => _connectingId = device.peripheral.uuid.toString());
    await _client.connectTo(device);
  }

  Future<void> _disconnect() async {
    await _client.disconnect();
    if (mounted) setState(() {});
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.primaryNavy,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _devicesSub?.cancel();
    _alertSub?.cancel();
    _pulseCtrl.dispose();
    // Don't stop client — keep paired in background
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primaryNavy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Bluetooth Devices',
            style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 17)),
        actions: [
          if (_status == PhoneBleStatus.paired)
            TextButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.bluetooth_disabled_rounded, size: 16, color: AppColors.error),
              label: Text('Unpair',
                  style: AppTypography.bodySmall(color: AppColors.error)
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.divider)),
      ),
      body: Column(children: [
        // ── Status header ──────────────────────────────────────────────────
        _buildStatusHeader(),

        // ── Main content ───────────────────────────────────────────────────
        Expanded(
          child: _status == PhoneBleStatus.paired
              ? _buildPairedView()
              : _buildScanView(),
        ),
      ]),

      // ── Bottom scan button ─────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Status Header ────────────────────────────────────────────────────────
  Widget _buildStatusHeader() {
    final Color color;
    final String label;
    final IconData icon;

    switch (_status) {
      case PhoneBleStatus.paired:
        color = AppColors.success;
        label = 'Connected to ${_client.pairedDeviceName}';
        icon = Icons.bluetooth_connected_rounded;
        break;
      case PhoneBleStatus.scanning:
        color = AppColors.accentNavy;
        label = 'Scanning for nearby devices…';
        icon = Icons.bluetooth_searching_rounded;
        break;
      case PhoneBleStatus.connecting:
        color = AppColors.warning;
        label = 'Pairing…';
        icon = Icons.bluetooth_searching_rounded;
        break;
      case PhoneBleStatus.disconnected:
        color = AppColors.error;
        label = 'Disconnected';
        icon = Icons.bluetooth_disabled_rounded;
        break;
      default:
        color = AppColors.textSecondary;
        label = 'Ready to scan';
        icon = Icons.bluetooth_rounded;
    }

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _status == PhoneBleStatus.scanning ? _pulseAnim.value : 1.0,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Status', style: AppTypography.metadata(color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(label,
                style: AppTypography.bodyMedium(color: color)
                    .copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
        // Signal / paired indicator
        if (_status == PhoneBleStatus.paired) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('LIVE', style: AppTypography.metadata(color: AppColors.success)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
            ]),
          ),
        ],
      ]),
    );
  }

  // ── Paired View ───────────────────────────────────────────────────────────
  Widget _buildPairedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Paired device card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryNavy, AppColors.accentNavy],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primaryNavy.withValues(alpha: 0.3),
                  blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.bluetooth_connected_rounded,
                    color: AppColors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_client.pairedDeviceName,
                    style: AppTypography.sectionTitle(color: AppColors.white)
                        .copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text('Connected · Alerts via Bluetooth',
                    style: AppTypography.metadata(color: AppColors.white.withValues(alpha: 0.75))),
              ])),
            ]),
            const SizedBox(height: 20),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 14),
            Text('You will receive alerts on this phone when a Connected user detects a name.',
                style: AppTypography.bodySmall(color: AppColors.white.withValues(alpha: 0.8))),
          ]),
        ),

        const SizedBox(height: 24),
        Text('How it works', style: AppTypography.sectionTitle(color: AppColors.textPrimary)
            .copyWith(fontSize: 15)),
        const SizedBox(height: 12),
        _buildStep('1', 'Connected phone starts listening', Icons.mic_rounded),
        _buildStep('2', 'Name detected by speech recognition', Icons.record_voice_over_rounded),
        _buildStep('3', 'Alert sent instantly via Bluetooth', Icons.bluetooth_rounded),
        _buildStep('4', 'This phone vibrates & shows notification', Icons.vibration_rounded),
      ]),
    );
  }

  Widget _buildStep(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: AppColors.badgeBackground, borderRadius: BorderRadius.circular(8)),
          child: Center(
            child: Text(number,
                style: AppTypography.bodyMedium(color: AppColors.primaryNavy)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Icon(icon, size: 16, color: AppColors.primaryNavy),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: AppTypography.bodySmall(color: AppColors.textPrimary))),
      ]),
    );
  }

  // ── Scan View ─────────────────────────────────────────────────────────────
  Widget _buildScanView() {
    if (_status == PhoneBleStatus.idle && _devices.isEmpty) {
      return _buildIdleEmpty();
    }

    if (_status == PhoneBleStatus.scanning && _devices.isEmpty) {
      return _buildScanning();
    }

    return _buildDeviceList();
  }

  Widget _buildIdleEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
                color: AppColors.badgeBackground, borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.bluetooth_rounded, size: 44, color: AppColors.primaryNavy),
          ),
          const SizedBox(height: 24),
          Text('Find Connected Devices',
              style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                  .copyWith(fontSize: 18)),
          const SizedBox(height: 10),
          Text(
            'Tap Scan below to find nearby Connected user phones. Make sure their VIBRO app is open.',
            style: AppTypography.bodySmall(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ]),
      ),
    );
  }

  Widget _buildScanning() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Transform.scale(
            scale: _pulseAnim.value,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 74, height: 74,
                  decoration: const BoxDecoration(
                      color: AppColors.primaryNavy, shape: BoxShape.circle),
                  child: const Icon(Icons.bluetooth_searching_rounded,
                      size: 36, color: AppColors.white),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Scanning…', style: AppTypography.sectionTitle(color: AppColors.textPrimary)
            .copyWith(fontSize: 18)),
        const SizedBox(height: 8),
        Text('Looking for nearby VIBRO Connected phones',
            style: AppTypography.bodySmall(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text('Make sure the Connected user\'s app is open',
            style: AppTypography.metadata(color: AppColors.textSecondary.withValues(alpha: 0.7))),
      ]),
    );
  }

  Widget _buildDeviceList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_status == PhoneBleStatus.scanning) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryNavy)),
              const SizedBox(width: 10),
              Text('Scanning in background…',
                  style: AppTypography.bodySmall(color: AppColors.primaryNavy)
                      .copyWith(fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
        Text('Available Devices (${_devices.length})',
            style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 14)),
        const SizedBox(height: 10),
        ..._devices.map((d) => _buildDeviceTile(d)),
      ],
    );
  }

  Widget _buildDeviceTile(DiscoveredVibroDevice device) {
    final id = device.peripheral.uuid.toString();
    final isConnecting = _connectingId == id;
    final signalBars = _signalBars(device.rssi);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6, offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              color: AppColors.primaryNavy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.phone_android_rounded,
              color: AppColors.primaryNavy, size: 24),
        ),
        title: Text(device.name,
            style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600)),
        subtitle: Row(children: [
          Icon(Icons.signal_wifi_4_bar_rounded, size: 13,
              color: signalBars > 2 ? AppColors.success : AppColors.warning),
          const SizedBox(width: 4),
          Text('${device.rssi} dBm · VIBRO-CONNECT',
              style: AppTypography.metadata(color: AppColors.textSecondary)),
        ]),
        trailing: isConnecting
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryNavy))
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(20)),
                child: Text('Pair', style: AppTypography.metadata(color: AppColors.white)
                    .copyWith(fontWeight: FontWeight.w700)),
              ),
        onTap: isConnecting ? null : () => _connectTo(device),
      ),
    );
  }

  int _signalBars(int rssi) {
    if (rssi >= -60) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -80) return 2;
    return 1;
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    if (_status == PhoneBleStatus.paired) return const SizedBox.shrink();

    final isScanning = _status == PhoneBleStatus.scanning;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: isScanning ? _stopScan : _startScan,
            style: ElevatedButton.styleFrom(
              backgroundColor: isScanning ? AppColors.error : AppColors.primaryNavy,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            icon: Icon(isScanning
                ? Icons.stop_rounded
                : Icons.bluetooth_searching_rounded, size: 20),
            label: Text(isScanning ? 'Stop Scanning' : 'Scan for Devices',
                style: AppTypography.bodyMedium(color: AppColors.white)
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
