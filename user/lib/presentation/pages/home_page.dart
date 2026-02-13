// VIBRO Home Page — White & Navy Enterprise
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/auth_service.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userName = 'User';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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

  Future<void> _signOut() async {
    try {
      await AuthService.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
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
        actions: [
          TextButton(
            onPressed: _signOut,
            child: Text(
              'Sign Out',
              style: AppTypography.metadata(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
                  subtitle: '0 trained',
                  statusColor: AppColors.accentNavy,
                ),
                _buildFeatureCard(
                  icon: Icons.search_rounded,
                  title: 'Detections',
                  subtitle: 'No activity',
                  statusColor: AppColors.textSecondary,
                ),
                _buildFeatureCard(
                  icon: Icons.location_on_rounded,
                  title: 'Locations',
                  subtitle: '0 configured',
                  statusColor: AppColors.success,
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

            const SizedBox(height: 32),
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
