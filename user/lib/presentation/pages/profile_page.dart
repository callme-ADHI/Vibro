// VIBRO Profile Page — User preferences + Identity management
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/location_service.dart';
import 'login_page.dart';
import 'locations_page.dart';
import '../../features/auth/screens/login_screen.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  int _locationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLocationCount();
  }

  Future<void> _loadLocationCount() async {
    try {
      final locs = await LocationService.instance.getLocations();
      if (mounted) setState(() => _locationCount = locs.length);
    } catch (_) {}
  }

  Future<void> _editUsername(String currentName) async {
    final controller = TextEditingController(text: currentName);
    String? errorText;

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Edit Name', style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18)),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            style: AppTypography.bodyLarge(color: AppColors.textPrimary),
            onChanged: (v) {
              if (errorText != null) setDialogState(() => errorText = null);
            },
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: AppTypography.bodyMedium(color: AppColors.textSecondary),
              errorText: errorText,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accentNavy, width: 1.5)),
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
                  setDialogState(() => errorText = 'Name cannot be empty');
                  return;
                }
                Navigator.of(ctx).pop(trimmed);
              },
              child: Text('Save', style: AppTypography.bodyMedium(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );

    if (newName != null && newName != currentName) {
      try {
        await AuthService.instance.updateUsername(newName);
        ref.read(userProvider.notifier).updateNameLocally(newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Name updated to "$newName"'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: ${e.toString().replaceFirst("Exception: ", "")}'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
    controller.dispose();
  }

  void _copyUserId(String uid) {
      Clipboard.setData(ClipboardData(text: uid));
      ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('User ID Copied to clipboard!'), behavior: SnackBarBehavior.floating, backgroundColor: AppColors.primaryNavy),
      );
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProvider);
    final String currentName = userProfile?['full_name'] ?? 'Loading...';
    final String email = userProfile?['email'] ?? '';
    final String userIdString = userProfile?['user_id'] ?? '...';
    final String userType = userProfile?['user_type'] ?? 'deaf';

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Profile',
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: AppColors.badgeBackground, borderRadius: BorderRadius.circular(14)),
                        child: Center(
                          child: Text(
                            currentName.isNotEmpty && currentName != 'Loading...' ? currentName[0].toUpperCase() : '?',
                            style: AppTypography.sectionTitle(color: AppColors.primaryNavy).copyWith(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentName,
                              style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(email, style: AppTypography.bodySmall(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _editUsername(currentName),
                        icon: const Icon(Icons.edit_outlined, color: AppColors.accentNavy, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // User ID Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('Your Unique ID', style: AppTypography.metadata(color: AppColors.textSecondary)),
                             const SizedBox(height: 4),
                             Text(
                               userIdString,
                               style: AppTypography.bodyLarge(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.bold, letterSpacing: 2),
                             ),
                           ],
                         ),
                         IconButton(
                           onPressed: () => _copyUserId(userIdString),
                           icon: const Icon(Icons.copy_rounded, color: AppColors.primaryNavy, size: 20),
                         )
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Hardware Integration'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.bluetooth_rounded,
                title: 'ESP32 Connection',
                subtitle: 'Not connected',
                trailing: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
              ),
              _buildSettingsTile(
                icon: Icons.volume_up_rounded,
                title: 'Ring Configuration',
                subtitle: 'Default pattern',
              ),
            ]),

            const SizedBox(height: 24),
            _buildSectionHeader('Preferences'),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.location_on_rounded,
                title: 'Location Mapping',
                subtitle: '$_locationCount locations configured',
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LocationsPage()));
                  _loadLocationCount();
                },
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
            // Sign Out
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text('Sign Out', style: AppTypography.bodyMedium(color: AppColors.error).copyWith(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      ref.read(userProvider.notifier).clearProfile();
      await AuthService.instance.signOut();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign out failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16, fontWeight: FontWeight.w600));
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
          if (index.isOdd) return const Divider(color: AppColors.divider, height: 1, indent: 56);
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required String subtitle, Widget? trailing, VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryNavy, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.bodySmall(color: AppColors.textSecondary)),
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: content);
    }
    return content;
  }
}
