import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/providers/logs_provider.dart';

class ConnectedUserDetailPage extends ConsumerStatefulWidget {
  final String targetId;
  final String targetName;

  const ConnectedUserDetailPage({super.key, required this.targetId, required this.targetName});

  @override
  ConsumerState<ConnectedUserDetailPage> createState() => _ConnectedUserDetailPageState();
}

class _ConnectedUserDetailPageState extends ConsumerState<ConnectedUserDetailPage> {
  bool _isLoading = false;
  String? _targetUUID;

  @override
  void initState() {
    super.initState();
    _fetchUUID();
  }

  Future<void> _fetchUUID() async {
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('user_id', widget.targetId)
          .maybeSingle();
      if (mounted && res != null) {
        setState(() => _targetUUID = res['id']);
      }
    } catch (_) {}
  }

  void _triggerAlert(String type) async {
    if (_targetUUID == null) return;
    
    setState(() => _isLoading = true);
    
    final success = await ref.read(logsProvider.notifier).triggerRemoteAlert(_targetUUID!, type);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert sent!'), backgroundColor: AppColors.success));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send alert.'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        title: Text(widget.targetName, style: AppTypography.pageTitle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryNavy),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.divider)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: AppColors.badgeBackground, borderRadius: BorderRadius.circular(14)),
                    child: Center(
                      child: Text(
                        widget.targetName.isNotEmpty ? widget.targetName[0].toUpperCase() : 'U',
                        style: AppTypography.sectionTitle(color: AppColors.primaryNavy).copyWith(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.targetName, style: AppTypography.sectionTitle(color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.divider)),
                          child: Text('ID: ${widget.targetId}', style: AppTypography.metadata(color: AppColors.textSecondary).copyWith(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            Text('Quick Alerts', style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            
            _buildAlertButton(
              title: 'Call Name',
              subtitle: 'Send a gentle "Name" vibration',
              icon: Icons.person_search_rounded,
              color: AppColors.primaryNavy,
              onTap: () => _triggerAlert('call_name'),
            ),
            const SizedBox(height: 12),
            _buildAlertButton(
              title: 'Attention',
              subtitle: 'Send a standard notification buzz',
              icon: Icons.notifications_active_rounded,
              color: AppColors.accentNavy,
              onTap: () => _triggerAlert('attention'),
            ),
            const SizedBox(height: 12),
            _buildAlertButton(
              title: 'Emergency',
              subtitle: 'High priority continuous vibration',
              icon: Icons.warning_rounded,
              color: AppColors.error,
              onTap: () => _triggerAlert('emergency'),
            ),
            
            const SizedBox(height: 48),
            // Remove connection
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remove coming soon')));
                },
                icon: const Icon(Icons.link_off_rounded, size: 18),
                label: Text('Remove Connection', style: AppTypography.bodyMedium(color: AppColors.error).copyWith(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertButton({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: _isLoading || _targetUUID == null ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: AppTypography.metadata(color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (_isLoading) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) else Icon(Icons.send_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
