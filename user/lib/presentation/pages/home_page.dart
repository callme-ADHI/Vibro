// VIBRO Home Page — White & Navy Enterprise (Tab Content)
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/training_service.dart';
import '../../core/services/location_service.dart';
import 'training_status_page.dart';
import 'locations_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = 'User';
  String _userEmail = '';
  TrainingStatus _trainingStatus = TrainingStatus.notStarted;
  int _trainingProgress = 0;
  int _modelCount = 0;
  int _locationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadTrainingStatus();
    _loadLocationCount();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        setState(() {
          _userEmail = user.email ?? '';
        });

        final response = await Supabase.instance.client
            .from('profiles')
            .select('username')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted && response != null && response['username'] != null) {
          setState(() {
            _userName = response['username'];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadTrainingStatus() async {
    final status = await TrainingService.instance.getCurrentStatus();
    if (mounted && status != null) {
      setState(() {
        _trainingStatus = status.status;
        _trainingProgress = status.progressPercentage;
      });
    }

    // Load trained models count
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final models = await Supabase.instance.client
            .from('trained_models')
            .select('id')
            .eq('user_id', user.id);
        if (mounted) {
          setState(() => _modelCount = (models as List).length);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadLocationCount() async {
    try {
      final locs = await LocationService.instance.getLocations();
      if (mounted) setState(() => _locationCount = locs.length);
    } catch (_) {}
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
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                        style: AppTypography.sectionTitle(color: AppColors.white).copyWith(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back',
                          style: AppTypography.metadata(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userName,
                          style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
                        ),
                        if (_userEmail.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _userEmail,
                            style: AppTypography.metadata(color: AppColors.textSecondary).copyWith(fontSize: 12),
                          ),
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
                _buildFeatureCard(
                  icon: Icons.record_voice_over_rounded,
                  title: 'Voice Models',
                  subtitle: '$_modelCount trained',
                  statusColor: _modelCount > 0 ? AppColors.success : AppColors.accentNavy,
                ),
                _buildFeatureCard(
                  icon: Icons.search_rounded,
                  title: 'Detections',
                  subtitle: 'No activity',
                  statusColor: AppColors.textSecondary,
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
                _buildFeatureCard(
                  icon: Icons.developer_board_rounded,
                  title: 'Device',
                  subtitle: 'Not connected',
                  statusColor: AppColors.warning,
                ),
              ],
            ),

            const SizedBox(height: 24),

            _buildSectionHeader('System Status'),
            const SizedBox(height: 12),

            _buildCard(
              child: Column(
                children: [
                  _buildStatusRow('ESP32 Device', 'Not Connected', AppColors.error),
                  const Divider(color: AppColors.divider, height: 1),
                  _buildStatusRow('Detection', 'Idle', AppColors.textSecondary),
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

            _buildCard(
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
                  Text(
                    '3 Voice Models  •  2 Locations',
                    style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                  ),
                ],
              ),
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
