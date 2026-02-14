// VIBRO Listening Page — Real-time name detection (speech_to_text, blablabala-style)
// https://github.com/callme-ADHI/blablabala
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../../core/services/recognition_service.dart';
import '../../core/services/name_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/history_service.dart';
import '../../core/services/kws_service.dart'; // DetectionEvent
import '../../core/services/ble_service.dart'; // BLE Integration
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'locations_page.dart';

class ListeningPage extends StatefulWidget {
  const ListeningPage({super.key});

  @override
  State<ListeningPage> createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage>
    with SingleTickerProviderStateMixin {
  final RecognitionService _recognition = RecognitionService.instance;
  final NameService _nameService = NameService.instance;
  final LocationService _locationService = LocationService.instance;
  final BleService _bleService = BleService.instance;
  
  // State from Service
  RecognitionState _recState = RecognitionState.IDLE;
  bool get _isListening => _recState == RecognitionState.LISTENING || 
                          _recState == RecognitionState.PROCESSING || 
                          _recState == RecognitionState.RESTARTING;

  bool _isReady = false;
  bool _isLoading = true;
  bool _isBleConnected = false;
  
  StreamSubscription<DetectionEvent>? _detectionSub;
  StreamSubscription<RecognitionState>? _stateSub;
  StreamSubscription<bool>? _bleSub;
  
  final List<DetectionEvent> _detections = [];
  List<String> _availableNames = [];
  final Set<String> _selectedNames = {};

  List<Map<String, dynamic>> _locations = [];
  String? _selectedLocationId;
  static const String _allNamesId = '__all__';

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initNotifications();
    _loadNamesAndInit();
    
    // BLE Init
    _bleService.initialize();
    _bleSub = _bleService.connectionStream.listen((connected) {
      if (mounted) setState(() => _isBleConnected = connected);
    });
    
    // Subscribe to Service Streams
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

    _detectionSub = _recognition.detectionStream.listen((event) {
      if (!mounted) return;
      
      setState(() {
        _detections.insert(0, event);
        if (_detections.length > 50) _detections.removeLast();
      });

      // Feedback & History
      _triggerFeedback(event);
      HistoryService.instance.insertDetection(
          nameLabel: event.name,
          confidence: event.confidence,
          locationId: _selectedLocationId == _allNamesId ? null : _selectedLocationId,
      );
    });
  }

  Future<void> _loadNamesAndInit() async {
    setState(() => _isLoading = true);
    try {
      final locations = await _locationService.getLocations();
      List<String> names;
      if (_selectedLocationId == null || _selectedLocationId == _allNamesId) {
        final namesData = await _nameService.getNames();
        names = namesData
            .map((n) => (n['name_label'] as String?) ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      } else {
        names = await _locationService.getNameLabelsForLocation(_selectedLocationId!);
      }
      if (mounted) {
        setState(() {
          _locations = locations;
          _availableNames = names;
          _selectedNames.clear();
          _selectedNames.addAll(names);
          _isReady = names.isNotEmpty;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locations = [];
          _availableNames = [];
          _selectedNames.clear();
          _isReady = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onLocationChanged(String? locationId) async {
    if (_selectedLocationId == locationId) return;
    // Stop listening if location changes
    if (_isListening) _stopListening();
    
    setState(() => _selectedLocationId = locationId);
    await _loadNamesAndInit();
  }

  Future<void> _initNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);

    final platform = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await platform?.requestNotificationsPermission();
  }

  void _toggleListening() {
    if (!_isReady || _selectedNames.isEmpty) return;

    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  void _startListening() async {
    // 1. Initialize with current names
    final initialized = await _recognition.initialize(_selectedNames);
    if (!initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
      return;
    }

    // 2. Start
    _recognition.startListening();
  }

  void _stopListening() {
    _recognition.stopListening();
  }
  
  Future<void> _triggerFeedback(DetectionEvent event) async {
    // 1. Phone Vibration
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 500);
    } else {
      HapticFeedback.heavyImpact();
    }
    
    // 2. Hardware LED (BLE)
    if (_isBleConnected) {
       _bleService.blinkLed();
    }

    // 3. Notification
    const androidDetails = AndroidNotificationDetails(
      'vibro_detections',
      'Detections',
      channelDescription: 'Notifications for detected names',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      0,
      'Name Detected',
      'Heard "${event.name}" (${(event.confidence * 100).toInt()}%)',
      details,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Detected: ${event.name} (${(event.confidence * 100).toInt()}%)',
            style: AppTypography.bodyMedium(color: AppColors.white),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _stopListening();
    _detectionSub?.cancel();
    _stateSub?.cancel();
    _bleSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Listening',
          style: AppTypography.pageTitle(color: AppColors.textPrimary)
              .copyWith(fontSize: 22),
        ),
        actions: [
          // BLE STATUS ICON
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isBleConnected ? AppColors.accentNavy.withValues(alpha: 0.1) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isBleConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                size: 20,
                color: _isBleConnected ? AppColors.accentNavy : AppColors.textSecondary.withValues(alpha: 0.3),
              ),
            ),
          ),
          
          if (_isListening)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: AppTypography.bodySmall(color: AppColors.success)
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Column(
        children: [
          // ── Top Section: Mic Button ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: _buildMicButton(),
          ),

          // ── Model Info Card ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildModelCard(),
          ),

          // ── Location Selector ──
          _buildLocationSelector(),

          // ── Name Selection Chips ──
          if (_isReady && _availableNames.isNotEmpty)
             _buildNameSelection(),

          const SizedBox(height: 10),

          // ── Detection Log Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Detection Log',
                  style: AppTypography.sectionTitle(color: AppColors.textPrimary),
                ),
                const Spacer(),
                if (_detections.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _detections.clear()),
                    child: Text(
                      'Clear',
                      style: AppTypography.bodySmall(color: AppColors.accentNavy)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Detection List ──
          Expanded(
            child: _detections.isEmpty
                ? _buildEmptyLog()
                : _buildDetectionList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  LOCATION SELECTOR
  // ═══════════════════════════════════════════

  Widget _buildLocationSelector() {
    final options = <String, String>{_allNamesId: 'All names'};
    for (final loc in _locations) {
      options[loc['id'] as String] = loc['location_name'] as String? ?? '';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Location',
                style: AppTypography.bodySmall(color: AppColors.textSecondary),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LocationsPage()),
                  );
                  _loadNamesAndInit();
                },
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('Manage'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accentNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...options.entries.map((e) {
                  final isSelected = _selectedLocationId == e.key ||
                      (_selectedLocationId == null && e.key == _allNamesId);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(e.value),
                      selected: isSelected,
                      onSelected: (_) => _onLocationChanged(e.key),
                      backgroundColor: AppColors.white,
                      selectedColor: AppColors.primaryNavy.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primaryNavy,
                      labelStyle: AppTypography.bodySmall(
                        color: isSelected ? AppColors.primaryNavy : AppColors.textPrimary,
                      ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? AppColors.primaryNavy : AppColors.divider,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  NAME SELECTION
  // ═══════════════════════════════════════════
  
  Widget _buildNameSelection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text(
            'Active Names',
            style: AppTypography.bodySmall(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableNames.map((name) {
              final isSelected = _selectedNames.contains(name);
              return FilterChip(
                label: Text(name),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedNames.add(name);
                    } else {
                      _selectedNames.remove(name);
                    }
                  });
                },
                backgroundColor: AppColors.white,
                selectedColor: AppColors.primaryNavy.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primaryNavy,
                labelStyle: AppTypography.bodySmall(
                  color: isSelected ? AppColors.primaryNavy : AppColors.textPrimary,
                ).copyWith(fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryNavy : AppColors.divider,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  MIC BUTTON
  // ═══════════════════════════════════════════

  Widget _buildMicButton() {
    return Column(
      children: [
        GestureDetector(
          onTap: _isLoading ? null : _toggleListening,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Container(
                width: 160,
                height: 160,
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
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _buttonColor,
                        boxShadow: _isListening
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryNavy.withValues(alpha: 0.25),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _isListening
                            ? Icons.mic_rounded
                            : (_isReady
                                ? Icons.mic_none_rounded
                                : Icons.mic_off_rounded),
                        size: 44,
                        color: _isListening || !_isReady
                            ? AppColors.white
                            : AppColors.primaryNavy,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 16),

        // Status text
        Text(
          _statusText,
          style: AppTypography.sectionTitle(color: AppColors.textPrimary)
              .copyWith(fontSize: 17),
        ),
        const SizedBox(height: 4),
        Text(
          _subtitleText,
          style: AppTypography.bodySmall(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Color get _buttonColor {
    if (_isLoading) return AppColors.textSecondary;
    if (_isListening) return AppColors.primaryNavy;
    if (!_isReady) return AppColors.textSecondary;
    return AppColors.white;
  }

  String get _statusText {
    if (_isLoading) return 'Loading...';
    if (!_isReady) return 'Add Names First';
    
    switch (_recState) {
      case RecognitionState.INITIALIZING:
        return 'Preparing mic...';
      case RecognitionState.LISTENING:
        return 'Listening...';
      case RecognitionState.PROCESSING:
        return 'Processing...';
      case RecognitionState.RESTARTING:
        return 'Reconnecting...';
      case RecognitionState.ERROR:
        return 'Mic Error';
      case RecognitionState.IDLE:
      default:
        return 'Ready';
    }
  }

  String get _subtitleText {
    if (_isLoading) return 'Please wait';
    if (!_isReady) return 'Add names to detect';
    
    switch (_recState) {
      case RecognitionState.INITIALIZING:
        return 'Starting speech engine';
      case RecognitionState.LISTENING:
        return 'Say a name to detect';
      case RecognitionState.PROCESSING:
        return 'Analyzing speech...';
      case RecognitionState.RESTARTING:
        return 'Refreshing session (auto)';
      case RecognitionState.ERROR:
        return 'Tap to retry';
      case RecognitionState.IDLE:
      default:
        return 'Tap to start listening';
    }
  }

  // ═══════════════════════════════════════════
  //  MODEL INFO CARD
  // ═══════════════════════════════════════════

  Widget _buildModelCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            'Engine',
            _isLoading
                ? 'Loading...'
                : (_isReady ? 'Speech-to-Text (ASR)' : 'Not ready'),
            _isReady ? AppColors.success : AppColors.error,
          ),
          const Divider(color: AppColors.divider, height: 20),
          _buildInfoRow(
            'Names',
            _isReady
                ? _availableNames.join(', ')
                : '—',
            _isReady ? AppColors.accentNavy : AppColors.textSecondary,
          ),
          const Divider(color: AppColors.divider, height: 20),
          _buildInfoRow(
            'Status',
            _recState.name, // "LISTENING", "IDLE", etc.
            _isListening ? AppColors.success : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  value,
                  style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  DETECTION LOG
  // ═══════════════════════════════════════════

  Widget _buildEmptyLog() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isListening
                  ? Icons.hearing_rounded
                  : Icons.format_list_bulleted_rounded,
              size: 40,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _isListening
                  ? 'Waiting for a voice match...'
                  : 'Detections will appear here',
              style: AppTypography.bodyMedium(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: _detections.length,
      separatorBuilder: (_, _a) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final det = _detections[index];
        final confidence = (det.confidence * 100).toStringAsFixed(1);
        final time =
            '${det.timestamp.hour.toString().padLeft(2, '0')}:${det.timestamp.minute.toString().padLeft(2, '0')}:${det.timestamp.second.toString().padLeft(2, '0')}';

        final isNew = index == 0 &&
            DateTime.now().difference(det.timestamp).inSeconds < 3;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isNew
                ? AppColors.success.withValues(alpha: 0.08)
                : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isNew ? AppColors.success.withValues(alpha: 0.3) : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              // Name avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    det.name.isNotEmpty
                        ? det.name[0].toUpperCase()
                        : '?',
                    style: AppTypography.sectionTitle(color: AppColors.primaryNavy)
                        .copyWith(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Name + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      det.name,
                      style:
                          AppTypography.bodyMedium(color: AppColors.textPrimary)
                              .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style:
                          AppTypography.bodySmall(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              // Confidence badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _confidenceColor(det.confidence).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$confidence%',
                  style: AppTypography.bodySmall(
                    color: _confidenceColor(det.confidence),
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.8) return AppColors.success;
    if (confidence >= 0.6) return AppColors.accentNavy;
    return AppColors.warning;
  }
}
