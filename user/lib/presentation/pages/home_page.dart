// VIBRO Home Page - Post-Login Dashboard
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/auth_service.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/vibro_card.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthService.instance;
  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _auth.getUserProfile();
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text('Sign Out', style: AppTypography.sectionTitle()),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTypography.bodyMedium(color: AppColors.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppTypography.bodyMedium(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: Text('Sign Out', style: AppTypography.bodyMedium(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentEmail ?? 'User';
    final username = _profile?['username'] as String?;
    final displayName = username ?? email.split('@').first;

    return Scaffold(
      backgroundColor: AppColors.deepNavy,
      appBar: AppBar(
        backgroundColor: AppColors.deepNavy,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.steelBlue.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  displayName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.steelBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.appName,
                    style: AppTypography.cardTitle(color: AppColors.primaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, color: AppColors.secondaryText),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              VibroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.waving_hand_rounded, color: AppColors.warning, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Welcome, $displayName!',
                            style: AppTypography.sectionTitle(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      email,
                      style: AppTypography.bodySmall(color: AppColors.secondaryText),
                    ),
                    if (_isLoadingProfile) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(
                        backgroundColor: AppColors.deepNavy,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.steelBlue),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Quick Stats Header
              Text(
                'Quick Access',
                style: AppTypography.sectionTitle(),
              ),

              const SizedBox(height: 16),

              // Feature Cards Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  _buildFeatureCard(
                    Icons.mic_rounded,
                    'Voice Models',
                    'Train & manage',
                    AppColors.steelBlue,
                  ),
                  _buildFeatureCard(
                    Icons.history_rounded,
                    'Detections',
                    'View history',
                    AppColors.success,
                  ),
                  _buildFeatureCard(
                    Icons.location_on_rounded,
                    'Locations',
                    'Manage zones',
                    AppColors.warning,
                  ),
                  _buildFeatureCard(
                    Icons.watch_rounded,
                    'Device',
                    'ESP32 Ring',
                    AppColors.confidenceMedium,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Status Card
              VibroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'System Status',
                          style: AppTypography.cardTitle(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStatusRow('Authentication', 'Connected', AppColors.success),
                    const SizedBox(height: 8),
                    _buildStatusRow('Backend', 'Supabase Active', AppColors.success),
                    const SizedBox(height: 8),
                    _buildStatusRow('ESP32 Device', 'Not Paired', AppColors.secondaryText),
                    const SizedBox(height: 8),
                    _buildStatusRow('Detection', 'Idle', AppColors.secondaryText),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Subscription Info
              VibroCard(
                child: Row(
                  children: [
                    const Icon(Icons.diamond_rounded, color: AppColors.steelBlue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Basic Plan',
                            style: AppTypography.cardTitle(),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '3 voice models • 2 locations',
                            style: AppTypography.bodySmall(color: AppColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.steelBlue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Active',
                        style: AppTypography.metadata(color: AppColors.steelBlue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String subtitle, Color color) {
    return VibroCard(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title — coming soon!'),
            backgroundColor: AppColors.steelBlue,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.cardTitle()),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.metadata(color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySmall(color: AppColors.secondaryText)),
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
            Text(value, style: AppTypography.bodySmall(color: statusColor)),
          ],
        ),
      ],
    );
  }
}
