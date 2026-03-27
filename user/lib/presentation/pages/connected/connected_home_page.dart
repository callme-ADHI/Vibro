// Connected User Home — BLE-first listening + alert pipeline
// 1. Scan/pair with Deaf phone via BLE
// 2. Speech recognition monitors assigned names
// 3. On detection → send via BLE (primary) OR DB (fallback)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/recognition_service.dart';
import '../../../core/services/kws_service.dart';
import '../../../core/services/wifi_service.dart';
import '../../../core/services/foreground_service.dart';

// ── Provider: fetch relations + assigned name labels ─────────────────────────
final connectedRelationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final me = Supabase.instance.client.auth.currentUser;
  if (me == null) return [];

  final relations = await Supabase.instance.client
      .from('user_relationships')
      .select('id, relation_label, deaf_user_id')
      .eq('connected_user_id', me.id);

  final List<Map<String, dynamic>> result = [];
  for (final rel in relations) {
    final models = await Supabase.instance.client
        .from('relation_models')
        .select('trained_names(id, name_label)')
        .eq('relation_id', rel['id']);

    final nameLabels = models
        .map((m) => (m['trained_names']?['name_label'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final deafProfile = await Supabase.instance.client
        .from('profiles')
        .select('full_name, user_id')
        .eq('id', rel['deaf_user_id'])
        .maybeSingle();

    result.add({
      'relation_id': rel['id'],
      'relation_label': rel['relation_label'] ?? 'Unknown',
      'deaf_user_id': rel['deaf_user_id'],
      'deaf_name': deafProfile?['full_name'] ?? 'Unknown',
      'deaf_text_id': deafProfile?['user_id'] ?? '',
      'name_labels': nameLabels,
    });
  }
  return result;
});

class ConnectedHomePage extends ConsumerStatefulWidget {
  const ConnectedHomePage({super.key});

  @override
  ConsumerState<ConnectedHomePage> createState() => _ConnectedHomePageState();
}

class _ConnectedHomePageState extends ConsumerState<ConnectedHomePage>
    with SingleTickerProviderStateMixin {
  // ── Services ──────────────────────────────────────────────────────────────
  final RecognitionService _recognition = RecognitionService.instance;
  final ConnectedPhoneWifiClient _wifi = ConnectedPhoneWifiClient.instance;

  // ── State ─────────────────────────────────────────────────────────────────
  RecognitionState _recState = RecognitionState.IDLE;
  PhoneWifiStatus _wifiStatus = PhoneWifiStatus.idle;

  bool get _isListening =>
      _recState == RecognitionState.LISTENING ||
      _recState == RecognitionState.PROCESSING ||
      _recState == RecognitionState.RESTARTING;

  List<Map<String, dynamic>> _relations = [];
  Set<String> _allNameLabels = {};
  final List<Map<String, dynamic>> _localLog = [];

  // ── Subscriptions ─────────────────────────────────────────────────────────
  StreamSubscription<DetectionEvent>? _detectionSub;
  StreamSubscription<RecognitionState>? _stateSub;
  StreamSubscription<PhoneWifiStatus>? _wifiSub;

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initNotifications();

    // Speech state
    _stateSub = _recognition.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _recState = state);
      if (_isListening) {
        if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      }
    });

    // Speech detections → WiFi alert
    _detectionSub = _recognition.detectionStream.listen(_onDetected);

    // WiFi status
    _wifiSub = _wifi.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _wifiStatus = status);
    });
    _wifiStatus = _wifi.status;

    // Start foreground service for background operation
    VibroForegroundService.instance.start(mode: 'connected');

    // Automatically hunt and seamlessly pair with Deaf device
    if (_wifiStatus == PhoneWifiStatus.idle || _wifiStatus == PhoneWifiStatus.disconnected) {
      _wifi.startAutoConnect().catchError((_) {});
    }
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(const InitializationSettings(android: android));
    final platform = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await platform?.requestNotificationsPermission();
  }

  // ── Relations loaded from provider ───────────────────────────────────────
  void _onRelationsLoaded(List<Map<String, dynamic>> relations) {
    _relations = relations;
    _allNameLabels = relations
        .expand((r) => (r['name_labels'] as List<dynamic>? ?? []).cast<String>())
        .toSet();
  }

  // ── WiFi scan/connect toggle ──────────────────────────────────────────────
  Future<void> _toggleBle() async {
    if (_wifiStatus == PhoneWifiStatus.paired || _wifiStatus == PhoneWifiStatus.scanning) {
      await _wifi.disconnect();
    } else {
      try {
        await _wifi.startAutoConnect();
      } catch (e) {
        _showSnack(e.toString(), error: true);
      }
    }
  }

  // ── Listening toggle ─────────────────────────────────────────────────────
  void _toggleListening() {
    if (_isListening) {
      _recognition.stopListening();
    } else {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (_allNameLabels.isEmpty) {
      _showSnack('No models assigned. Ask your Deaf user to assign models first.',
          error: true);
      return;
    }
    // Auto-start WiFi scan so Deaf phone can be found
    if (_wifiStatus == PhoneWifiStatus.idle || _wifiStatus == PhoneWifiStatus.disconnected) {
      _wifi.startAutoConnect().catchError((e) {
        _showSnack(e.toString(), error: true);
      });
    }
    final initialized = await _recognition.initialize(_allNameLabels);
    if (!initialized) {
      _showSnack('Speech recognition not available.', error: true);
      return;
    }
    _recognition.startListening();
  }

  // ── Detection handler → BLE primary, DB fallback ─────────────────────────
  Future<void> _onDetected(DetectionEvent event) async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;

    for (final rel in _relations) {
      final labels = (rel['name_labels'] as List<dynamic>? ?? []).cast<String>();
      if (labels.any((l) => l.toLowerCase() == event.name.toLowerCase())) {
        final label = rel['relation_label'] as String;
        final deafUserId = rel['deaf_user_id'] as String;
        final deafName = rel['deaf_name'] as String;

        final payload = PhoneAlertPayload(
          label: label,
          name: event.name,
          confidence: event.confidence,
        );

        // ── Primary: WiFi ──
        bool sentViaWifi = false;
        if (_wifiStatus == PhoneWifiStatus.paired) {
          sentViaWifi = await _wifi.sendAlert(payload);
        }

        // ── Fallback: DB ──
        if (!sentViaWifi) {
          try {
            await Supabase.instance.client.from('relation_alerts').insert({
              'deaf_user_id': deafUserId,
              'connected_user_id': me.id,
              'relation_label': label,
              'model_name': event.name,
              'confidence': event.confidence,
            });
          } catch (_) {}
        }

        // ── Local log + feedback ──
        if (mounted) {
          setState(() {
            _localLog.insert(0, {
              'name': event.name,
              'confidence': event.confidence,
              'deaf_name': deafName,
              'relation_label': label,
              'timestamp': event.timestamp,
              'via_ble': sentViaWifi,
            });
            if (_localLog.length > 30) _localLog.removeLast();
          });
        }

        _triggerConnectedFeedback(event.name, label, event.confidence, sentViaWifi);
        break;
      }
    }
  }

  Future<void> _triggerConnectedFeedback(
      String name, String label, double confidence, bool viaWifi) async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 300);
    } else {
      HapticFeedback.heavyImpact();
    }

    await _notifications.show(
      0,
      '🎙️ You called "$name"!',
      'Alert sent to $label via ${viaWifi ? "WiFi" : "internet"}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'vibro_connected', 'Connected Alerts',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    _showSnack('You called "$name" → $label notified via ${viaWifi ? "WiFi" : "internet"}');
  }

  Future<void> _sendManualAlert(String deafUserId, String label) async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;

    bool sentViaWifi = false;
    if (_wifiStatus == PhoneWifiStatus.paired) {
      sentViaWifi = await _wifi.sendAlert(PhoneAlertPayload(
        label: label, name: 'manual', confidence: 1.0,
      ));
    }
    if (!sentViaWifi) {
      try {
        await Supabase.instance.client.from('relation_alerts').insert({
          'deaf_user_id': deafUserId,
          'connected_user_id': me.id,
          'relation_label': label,
          'model_name': 'manual',
          'confidence': 1.0,
        });
      } catch (e) {
        _showSnack('Failed to send alert.', error: true);
        return;
      }
    }
    _showSnack('Manual alert sent via ${sentViaWifi ? "WiFi" : "internet"}');
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _recognition.stopListening();
    _detectionSub?.cancel();
    _stateSub?.cancel();
    _wifiSub?.cancel();
    // Keep WiFi client alive in background for reconnect
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final relationsAsync = ref.watch(connectedRelationsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: _buildAppBar(),
      body: relationsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (relations) {
          _onRelationsLoaded(relations);
          return _buildBody(relations);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.people_alt_rounded, size: 18, color: AppColors.white),
        ),
        const SizedBox(width: 10),
        Text('VIBRO CONNECT',
            style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                .copyWith(letterSpacing: 2, fontSize: 16)),
      ]),
      actions: [
        // BLE Pair Button
        GestureDetector(
          onTap: _toggleBle,
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _bleBadgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _bleBadgeColor.withValues(alpha: 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_bleIcon, size: 14, color: _bleBadgeColor),
              const SizedBox(width: 5),
              Text(_bleLabel,
                  style: AppTypography.metadata(color: _bleBadgeColor)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
            ]),
          ),
        ),
        // LIVE badge
        if (_isListening)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('LIVE', style: AppTypography.metadata(color: AppColors.success)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 11)),
            ]),
          ),
      ],
      bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider)),
    );
  }

  // ── BLE badge helpers ──────────────────────────────────────────────────────
  Color get _bleBadgeColor {
    switch (_wifiStatus) {
      case PhoneWifiStatus.paired: return AppColors.success;
      case PhoneWifiStatus.scanning: return AppColors.accentNavy;
      case PhoneWifiStatus.connecting: return AppColors.warning;
      default: return AppColors.textSecondary;
    }
  }

  IconData get _bleIcon {
    switch (_wifiStatus) {
      case PhoneWifiStatus.paired: return Icons.wifi_rounded;
      case PhoneWifiStatus.scanning: return Icons.wifi_find_rounded;
      case PhoneWifiStatus.connecting: return Icons.wifi_find_rounded;
      default: return Icons.wifi_off_rounded;
    }
  }

  String get _bleLabel {
    switch (_wifiStatus) {
      case PhoneWifiStatus.paired: return 'PAIRED';
      case PhoneWifiStatus.scanning: return 'SCANNING';
      case PhoneWifiStatus.connecting: return 'JOINING';
      default: return 'CONNECT';
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BODY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBody(List<Map<String, dynamic>> relations) {
    return SingleChildScrollView(
      child: Column(children: [
        // WiFi status banner
        if (_wifiStatus != PhoneWifiStatus.paired) _buildWifiBanner(),

        // Mic section
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _buildMicSection(),
        ),

        // Relation cards
        if (relations.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildRelationCards(relations),
          ),

        const SizedBox(height: 14),

        // Log header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Text('Detection Log',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                    .copyWith(fontSize: 15)),
            const Spacer(),
            if (_localLog.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _localLog.clear()),
                child: Text('Clear',
                    style: AppTypography.bodySmall(color: AppColors.primaryNavy)
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        _localLog.isEmpty ? _buildEmptyLog() : _buildLogList(),
        const SizedBox(height: 40),
      ]),
    );
  }


  // ── WiFi status banner ───────────────────────────────────────────────────
  Widget _buildWifiBanner() {
    final isSearching = _wifiStatus == PhoneWifiStatus.scanning ||
        _wifiStatus == PhoneWifiStatus.connecting;

    return GestureDetector(
      onTap: _toggleBle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSearching
            ? AppColors.warning.withValues(alpha: 0.12)
            : AppColors.primaryNavy.withValues(alpha: 0.07),
        child: Row(children: [
          if (isSearching)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
            )
          else
            Icon(Icons.wifi_off_rounded,
                size: 16, color: AppColors.primaryNavy.withValues(alpha: 0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isSearching
                  ? 'Scanning WiFi for Deaf device…'
                  : 'Tap to scan for Deaf device on WiFi',
              style: AppTypography.metadata(
                  color: isSearching ? AppColors.warning : AppColors.primaryNavy)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 16,
              color: isSearching ? AppColors.warning : AppColors.primaryNavy.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }


  // ── Mic button ─────────────────────────────────────────────────────────────
  Widget _buildMicSection() {
    final hasModels = _allNameLabels.isNotEmpty;
    return Column(children: [
      GestureDetector(
        onTap: hasModels ? _toggleListening : null,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening
                  ? AppColors.primaryNavy.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: Center(
              child: Transform.scale(
                scale: _isListening ? _pulseAnim.value : 1.0,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening
                        ? AppColors.primaryNavy
                        : hasModels
                            ? AppColors.white
                            : AppColors.textSecondary.withValues(alpha: 0.2),
                    boxShadow: _isListening
                        ? [BoxShadow(
                            color: AppColors.primaryNavy.withValues(alpha: 0.3),
                            blurRadius: 20, spreadRadius: 4)]
                        : [BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Icon(
                    _isListening
                        ? Icons.mic_rounded
                        : hasModels ? Icons.mic_none_rounded : Icons.mic_off_rounded,
                    size: 38,
                    color: _isListening
                        ? AppColors.white
                        : hasModels ? AppColors.primaryNavy : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _isListening ? 'Listening...' : hasModels ? 'Tap to Start' : 'No Models',
        style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16),
      ),
      const SizedBox(height: 3),
      Text(
        _isListening
            ? 'Monitoring: ${_allNameLabels.join(", ")}'
            : hasModels
                ? '${_allNameLabels.length} name(s) · alerts via ${_wifiStatus == PhoneWifiStatus.paired ? "WiFi" : "internet"}'
                : 'Ask Deaf user to assign models',
        style: AppTypography.bodySmall(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  // ── Relation cards ────────────────────────────────────────────────────────
  Widget _buildRelationCards(List<Map<String, dynamic>> relations) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Linked Deaf Users',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary)
              .copyWith(fontSize: 15)),
      const SizedBox(height: 8),
      ...relations.map((rel) {
        final label = rel['relation_label'] as String;
        final deafName = rel['deaf_name'] as String;
        final deafId = rel['deaf_user_id'] as String;
        final names = (rel['name_labels'] as List<dynamic>? ?? []).cast<String>();

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 18, backgroundColor: AppColors.badgeBackground,
                child: Text(
                  deafName.isNotEmpty ? deafName[0].toUpperCase() : 'D',
                  style: const TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(deafName,
                    style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600)),
                Text('They call you: $label',
                    style: AppTypography.metadata(color: AppColors.primaryNavy)
                        .copyWith(fontWeight: FontWeight.w600)),
              ])),
              GestureDetector(
                onTap: () => _sendManualAlert(deafId, label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.notifications_active_rounded, size: 14, color: AppColors.white),
                    const SizedBox(width: 4),
                    Text('Alert', style: AppTypography.metadata(color: AppColors.white)
                        .copyWith(fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
            if (names.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 4,
                children: names.map((n) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.badgeBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2))),
                  child: Text(n,
                      style: AppTypography.metadata(color: AppColors.primaryNavy)
                          .copyWith(fontWeight: FontWeight.w600)),
                )).toList(),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('No models assigned yet',
                    style: AppTypography.metadata(color: AppColors.textSecondary)),
              ),
          ]),
        );
      }),
    ]);
  }

  // ── Empty log ─────────────────────────────────────────────────────────────
  Widget _buildEmptyLog() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          _isListening ? Icons.hearing_rounded : Icons.format_list_bulleted_rounded,
          size: 36, color: AppColors.textSecondary.withValues(alpha: 0.35),
        ),
        const SizedBox(height: 10),
        Text(
          _isListening ? 'Waiting for a voice match...' : 'Detections appear here',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
      ]),
    );
  }

  // ── Detection log ─────────────────────────────────────────────────────────
  Widget _buildLogList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _localLog.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final log = _localLog[index];
        final ts = log['timestamp'] as DateTime;
        final pct = ((log['confidence'] as double) * 100).toInt();
        final viaBle = log['via_ble'] as bool? ?? false;
        final timeStr =
            '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
        final isNew = index == 0 && DateTime.now().difference(ts).inSeconds < 4;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: isNew
                  ? AppColors.primaryNavy.withValues(alpha: 0.06)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isNew
                      ? AppColors.primaryNavy.withValues(alpha: 0.3)
                      : AppColors.divider)),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: isNew ? AppColors.primaryNavy : AppColors.badgeBackground,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.record_voice_over_rounded,
                  color: isNew ? AppColors.white : AppColors.primaryNavy, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(log['name'] as String,
                  style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600)),
              Text('→ ${log['deaf_name']} (${log['relation_label']})',
                  style: AppTypography.metadata(color: AppColors.textSecondary)),
              Row(children: [
                Text(timeStr, style: AppTypography.metadata(color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Icon(
                  viaBle ? Icons.bluetooth_rounded : Icons.cloud_rounded,
                  size: 11,
                  color: viaBle ? AppColors.accentNavy : AppColors.textSecondary,
                ),
                const SizedBox(width: 2),
                Text(
                  viaBle ? 'BLE' : 'Internet',
                  style: AppTypography.metadata(
                          color: viaBle ? AppColors.accentNavy : AppColors.textSecondary)
                      .copyWith(fontSize: 10),
                ),
              ]),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('$pct%',
                  style: AppTypography.metadata(color: AppColors.success)
                      .copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
        );
      },
    );
  }
}
