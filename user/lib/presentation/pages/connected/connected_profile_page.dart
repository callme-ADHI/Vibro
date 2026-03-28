import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../features/auth/services/auth_service.dart';
import '../../../features/auth/controllers/auth_controller.dart';
import '../../../core/providers/user_provider.dart';
import '../../../features/auth/screens/login_screen.dart';

class ConnectedProfilePage extends ConsumerStatefulWidget {
  const ConnectedProfilePage({super.key});

  @override
  ConsumerState<ConnectedProfilePage> createState() => _ConnectedProfilePageState();
}

class _ConnectedProfilePageState extends ConsumerState<ConnectedProfilePage> {
  Future<void> _editUsername(String currentName) async {
    final controller = TextEditingController(text: currentName);
    String? errorText;

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.white,
          title: const Text('Edit Name'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(errorText: errorText),
            onChanged: (v) { if (errorText != null) setDialogState(() => errorText = null); },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                final t = controller.text.trim();
                if (t.isEmpty) { setDialogState(() => errorText = 'Cannot be empty'); return; }
                Navigator.of(ctx).pop(t);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (newName != null && newName != currentName) {
      try {
        await ref.read(authServiceProvider).updateUsername(newName);
        ref.read(userProvider.notifier).updateNameLocally(newName);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  void _copyUserId(String uid) {
      Clipboard.setData(ClipboardData(text: uid));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID Copied!'), backgroundColor: AppColors.primaryNavy));
  }

  Future<void> _signOut() async {
    ref.read(userProvider.notifier).clearProfile();
    await ref.read(authServiceProvider).signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProvider);
    final String currentName = userProfile?['full_name'] ?? 'Loading...';
    final String email = userProfile?['email'] ?? '';
    final String userIdString = userProfile?['user_id'] ?? '...';

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        title: Text('Profile', style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22)),
        backgroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.divider)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: AppColors.badgeBackground, borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text(currentName.isNotEmpty ? currentName[0] : '?', style: AppTypography.sectionTitle(color: AppColors.primaryNavy).copyWith(fontSize: 22))),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(currentName, style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600, fontSize: 16)),
                            Text(email, style: AppTypography.bodySmall(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => _editUsername(currentName), icon: const Icon(Icons.edit_outlined, color: AppColors.accentNavy, size: 22)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('Connected ID', style: AppTypography.metadata(color: AppColors.textSecondary)),
                             Text(userIdString, style: AppTypography.bodyLarge(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.bold, letterSpacing: 2)),
                           ],
                         ),
                         IconButton(onPressed: () => _copyUserId(userIdString), icon: const Icon(Icons.copy_rounded, color: AppColors.primaryNavy, size: 20))
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Settings', style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
              child: ListTile(
                leading: const Icon(Icons.notifications_outlined, color: AppColors.primaryNavy),
                title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w500)),
                trailing: Switch(value: true, activeColor: AppColors.primaryNavy, onChanged: (v) {}),
              )
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text('Sign Out', style: AppTypography.bodyMedium(color: AppColors.error).copyWith(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error, width: 1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
