// VIBRO Home Page — White & Navy Enterprise (Tab Content)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/training_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/ble_service.dart';
import '../../core/services/phone_ble_service.dart';
import '../../core/providers/user_provider.dart';
import 'training_status_page.dart';
import 'locations_page.dart';
import 'settings_page.dart';
import 'history_page.dart';
import 'ble_devices_page.dart';
import 'detection_log_page.dart';
import 'subscription_page.dart';

class HomePage extends ConsumerStatefulWidget {
  final void Function(int)? onNavigateToTab;
  const HomePage({super.key, this.onNavigateToTab});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<Map<String, dynamic>> _recentHistories = [];
  TrainingStatus _trainingStatus = TrainingStatus.notStarted;
  int _trainingProgress = 0;
  int _modelCount = 0;
  int _locationCount = 0;
  int _detectionCount = 0; // Added detection count
  bool _isBleConnected = false;
  PhoneBleStatus _phoneBleStatus = PhoneBleStatus.idle;

  Timer? _refreshTimer;
  StreamSubscription? _bleSub;
  StreamSubscription<PhoneBleStatus>? _phoneBleStatusSub;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    
    // Auto refresh every 5s
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadAllData());

    // BLE Status (ESP32)
    _bleSub = BleService.instance.connectionStream.listen((connected) {
       if (mounted) setState(() => _isBleConnected = connected);
    });
    _isBleConnected = BleService.instance.isConnected;

    // Phone BLE status (Connected user pairing)
    _phoneBleStatus = DeafPhoneBleClient.instance.status;
    _phoneBleStatusSub = DeafPhoneBleClient.instance.statusStream.listen((s) {
      if (mounted) setState(() => _phoneBleStatus = s);
    });
  }
  
  void _loadAllData() {
    _loadTrainingStatus();
    _loadLocationCount();
    _loadDetectionCount();
    _loadRecentHistories();
  }

  Future<void> _loadRecentHistories() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String();

      final response = await Supabase.instance.client
          .from('detection_history')
          .select('detected_label, confidence, created_at')
          .eq('user_id', user.id)
          .gte('created_at', oneHourAgo)
          .order('created_at', ascending: false)
          .limit(10);

      if (mounted) setState(() => _recentHistories = List<Map<String, dynamic>>.from(response));
    } catch (_) {}
  }

  Future<void> _loadTrainingStatus() async {
    final status = await TrainingService.instance.getCurrentStatus();
    if (mounted && status != null) {
      if (_trainingStatus != status.status || _trainingProgress != status.progressPercentage) {
          setState(() {
            _trainingStatus = status.status;
            _trainingProgress = status.progressPercentage;
          });
      }
    }

    // Load trained models count (names)
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final count = await Supabase.instance.client
            .from('trained_names')
            .count(CountOption.exact)
            .eq('user_id', user.id); 
        
        if (mounted && _modelCount != count) {
          setState(() => _modelCount = count);
        }
      }
    } catch (_) {}
  }
  
  Future<void> _loadDetectionCount() async {
      try {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
               // Get count of detections
               final count = await Supabase.instance.client
                .from('detection_history')
                .count(CountOption.exact)
                .eq('user_id', user.id);
               
               if (mounted && _detectionCount != count) {
                   setState(() => _detectionCount = count);
               }
          }
      } catch (_) {}
  }

  Future<void> _loadLocationCount() async {
    try {
      final locs = await LocationService.instance.getLocations();
      if (mounted && _locationCount != locs.length) setState(() => _locationCount = locs.length);
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _bleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProvider);
    final String currentName = userProfile?['full_name'] ?? 'Loading...';
    final String currentEmail = userProfile?['email'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.graphic_eq_rounded, size: 18, color: AppColors.white),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'VIBRO',
              style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(
                letterSpacing: 2,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
            icon: const Icon(Icons.account_circle_outlined, color: AppColors.primaryNavy, size: 28),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            _buildCard(
              child: Row(
                children: [
                   Container(
                     width: 48,
                     height: 48,
                     decoration: BoxDecoration(
                       color: AppColors.primaryNavy,
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Center(
                       child: Text(
                         currentName.isNotEmpty && currentName != 'Loading...' ? currentName[0].toUpperCase() : 'U',
                         style: AppTypography.sectionTitle(color: AppColors.white).copyWith(fontSize: 20),
                       ),
                     ),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('Welcome back', style: AppTypography.metadata(color: AppColors.textSecondary)),
                         const SizedBox(height: 2),
                         Text(currentName, style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18)),
                         if (currentEmail.isNotEmpty) ...[
                           const SizedBox(height: 2),
                           Text(currentEmail, style: AppTypography.metadata(color: AppColors.textSecondary).copyWith(fontSize: 12)),
                         ],
                       ],
                     ),
                   ),
                 ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Features'),
            const SizedBox(height: 12),

            // Feature Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.15,
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.onNavigateToTab != null) {
                      widget.onNavigateToTab!(3);
                    }
                  },
                  child: _buildFeatureCard(
                    icon: Icons.record_voice_over_rounded,
                    title: 'Voice Models',
                    subtitle: '$_modelCount active',
                    statusColor: _modelCount > 0 ? AppColors.success : AppColors.accentNavy,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DetectionLogPage()),
                  ),
                  child: _buildFeatureCard(
                    icon: Icons.history_rounded,
                    title: 'Detections',
                    subtitle: '$_detectionCount total',
                    statusColor: _detectionCount > 0 ? AppColors.success : AppColors.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LocationsPage()),
                    );
                    _loadLocationCount();
                  },
                  child: _buildFeatureCard(
                    icon: Icons.location_on_rounded,
                    title: 'Locations',
                    subtitle: '$_locationCount configured',
                    statusColor: _locationCount > 0 ? AppColors.success : AppColors.accentNavy,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BleDevicesPage()),
                  ),
                  child: _buildFeatureCard(
                    icon: _phoneBleStatus == PhoneBleStatus.paired
                        ? Icons.bluetooth_connected_rounded
                        : Icons.developer_board_rounded,
                    title: 'Device',
                    subtitle: _phoneBleStatus == PhoneBleStatus.paired
                        ? 'BLE Paired'
                        : _isBleConnected ? 'ESP32 Connected' : 'Tap to pair',
                    statusColor: _phoneBleStatus == PhoneBleStatus.paired
                        ? AppColors.success
                        : _isBleConnected ? AppColors.accentNavy : AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('System Status'),
            const SizedBox(height: 12),

            _buildCard(
              child: Column(
                children: [
                  _buildStatusRow(
                      'ESP32 Device', 
                      _isBleConnected ? 'Online' : 'Offline', 
                      _isBleConnected ? AppColors.success : AppColors.error
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildStatusRow(
                      'Phone BLE',
                      _phoneBleStatus == PhoneBleStatus.paired
                          ? 'Paired · ${DeafPhoneBleClient.instance.pairedDeviceName}'
                          : _phoneBleStatus == PhoneBleStatus.scanning ? 'Scanning…' : 'Not paired',
                      _phoneBleStatus == PhoneBleStatus.paired ? AppColors.success : AppColors.textSecondary,
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildStatusRow(
                      'Detection', 
                      'Ready', 
                      AppColors.success
                  ),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildStatusRow('Cloud Sync', 'Active', AppColors.success),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('Model Training'),
            const SizedBox(height: 12),
            _buildTrainingCard(),

            const SizedBox(height: 24),

            _buildSectionHeader('Subscription'),
            const SizedBox(height: 12),

            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionPage()),
              ),
              child: _buildCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'BASIC',
                        style: AppTypography.metadata(color: AppColors.white).copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '3 Voice Models  •  2 Locations',
                          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Recent Detections (Past Hour)'),
                GestureDetector(
                  onTap: () {
                     Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryPage()));
                  },
                  child: Text('View All', style: AppTypography.bodySmall(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_recentHistories.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Center(
                  child: Text('No detections in the past hour.', style: AppTypography.bodySmall(color: AppColors.textSecondary)),
                ),
              )
            else
              Column(
                children: _recentHistories.map((log) {
                  final String label = (log['detected_label'] ?? 'Unknown').toString();
                  final double confidence = ((log['confidence'] ?? 0.0) as num).toDouble();
                  final String timeString = log['created_at'] != null
                      ? DateTime.parse(log['created_at']).toLocal().toString().split('.').first
                      : '';
                  final int pct = (confidence * 100).round();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: AppColors.badgeBackground, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.waves_rounded, color: AppColors.primaryNavy, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(label, style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(timeString, style: AppTypography.metadata(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('$pct%', style: AppTypography.metadata(color: AppColors.success).copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingCard() {
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    switch (_trainingStatus) {
      case TrainingStatus.notStarted:
        statusColor = AppColors.textSecondary;
        statusText = 'Not trained yet';
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case TrainingStatus.downloadingAudio:
      case TrainingStatus.training:
      case TrainingStatus.uploadingModel:
        statusColor = AppColors.accentNavy;
        statusText = _trainingStatus.displayText;
        statusIcon = Icons.model_training_rounded;
        break;
      case TrainingStatus.completed:
        statusColor = AppColors.success;
        statusText = 'Model Ready';
        statusIcon = Icons.check_circle_rounded;
        break;
      case TrainingStatus.failed:
        statusColor = AppColors.error;
        statusText = 'Training Failed';
        statusIcon = Icons.error_rounded;
        break;
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TrainingStatusPage()),
        );
        _loadTrainingStatus();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice Model',
                    style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(statusText, style: AppTypography.bodySmall(color: statusColor)),
                  if (_trainingStatus.isInProgress) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _trainingProgress / 100,
                        backgroundColor: AppColors.divider,
                        color: AppColors.primaryNavy,
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  // ──────────────── Builders ────────────────

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primaryNavy, size: 26),
          const SizedBox(height: 14),
          Text(
            title,
            style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                subtitle,
                style: AppTypography.metadata(color: AppColors.textSecondary).copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium(color: AppColors.textSecondary).copyWith(fontSize: 14),
          ),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
