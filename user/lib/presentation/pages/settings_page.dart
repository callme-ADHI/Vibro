// VIBRO Settings Page — User preferences
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/auth_service.dart';
import 'login_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
          'Settings',
          style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22),
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
            // Device Section
            _buildSectionHeader('Device'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.bluetooth_rounded,
                title: 'ESP32 Connection',
                subtitle: 'Not connected',
                trailing: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              _buildSettingsTile(
                icon: Icons.volume_up_rounded,
                title: 'Ring Configuration',
                subtitle: 'Default pattern',
              ),
            ]),

            const SizedBox(height: 24),

            // Detection Section
            _buildSectionHeader('Detection'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.location_on_rounded,
                title: 'Location Mapping',
                subtitle: '0 locations configured',
              ),
              _buildSettingsTile(
                icon: Icons.tune_rounded,
                title: 'Sensitivity',
                subtitle: 'Normal',
              ),
              _buildSettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Enabled',
              ),
            ]),

            const SizedBox(height: 24),

            // Account Section
            _buildSectionHeader('Account'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Profile',
                subtitle: 'Manage account details',
              ),
              _buildSettingsTile(
                icon: Icons.workspace_premium_rounded,
                title: 'Subscription',
                subtitle: 'Basic plan',
              ),
            ]),

            const SizedBox(height: 24),

            // Sign Out
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  'Sign Out',
                  style: AppTypography.bodyMedium(color: AppColors.error).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await AuthService.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return const Divider(color: AppColors.divider, height: 1, indent: 56);
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryNavy, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          trailing ??
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
        ],
      ),
    );
  }
}
