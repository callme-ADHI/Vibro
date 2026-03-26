import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/providers/logs_provider.dart';

class ConnectedLogsPage extends ConsumerWidget {
  const ConnectedLogsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(logsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        title: Text('Activity Logs', style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22)),
        backgroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: AppColors.divider)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primaryNavy),
            onPressed: () => ref.read(logsProvider.notifier).loadLogs(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sent Alerts', style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            
            if (logs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
                child: const Center(child: Text('No alerts triggered yet.', style: TextStyle(color: AppColors.textSecondary))),
              )
            else
              Column(
                children: logs.map((log) {
                  final String rawLabel = (log['alert_type'] ?? 'remote_alert').toString();
                  final String targetName = (log['target_name'] ?? 'Unknown').toString();
                  final String timeString = log['created_at'] != null ? DateTime.parse(log['created_at']).toLocal().toString().split('.').first : '';
                  final bool delivered = log['delivered'] ?? false;
                  
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
                        Icon(rawLabel == 'emergency' ? Icons.warning_rounded : Icons.notifications_active_rounded, 
                             color: rawLabel == 'emergency' ? AppColors.error : AppColors.primaryNavy, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('To: $targetName', style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('$rawLabel ($timeString)', style: AppTypography.metadata(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: delivered ? AppColors.success.withOpacity(0.1) : AppColors.accentNavy.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)
                          ),
                          child: Text(delivered ? 'DELIVERED' : 'SENT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: delivered ? AppColors.success : AppColors.accentNavy)),
                        )
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
