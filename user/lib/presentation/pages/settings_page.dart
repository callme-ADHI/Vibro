// VIBRO Settings Page — User preferences + username edit
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/auth_service.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _username = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    final profile = await AuthService.instance.getUserProfile();

    if (mounted) {
      setState(() {
        _email = user?.email ?? '';
        _username = profile?['username'] ?? '';
      });
    }
  }

  Future<void> _editUsername() async {
    final controller = TextEditingController(text: _username);
    String? errorText;

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(
            'Edit Username',
            style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            style: AppTypography.bodyLarge(color: AppColors.textPrimary),
            onChanged: (v) {
              if (errorText != null) {
                setDialogState(() => errorText = null);
              }
            },
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: AppTypography.bodyMedium(color: AppColors.textSecondary),
              errorText: errorText,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accentNavy, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isEmpty) {
                  setDialogState(() => errorText = 'Username cannot be empty');
                  return;
                }
                Navigator.of(ctx).pop(trimmed);
              },
              child: Text(
                'Save',
                style: AppTypography.bodyMedium(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );

    if (newName != null && newName != _username) {
      try {
        await AuthService.instance.updateUsername(newName);
        setState(() => _username = newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Username updated to "$newName"'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
    controller.dispose();
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
            // Profile Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.badgeBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _username.isNotEmpty ? _username[0].toUpperCase() : '?',
                        style: AppTypography.sectionTitle(color: AppColors.primaryNavy).copyWith(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _username.isNotEmpty ? _username : 'No username set',
                          style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _email,
                          style: AppTypography.bodySmall(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _editUsername,
                    icon: const Icon(Icons.edit_outlined, color: AppColors.accentNavy, size: 20),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

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
