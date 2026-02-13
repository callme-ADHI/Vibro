// VIBRO History Page — Detection timeline
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

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
          'History',
          style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
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
                  _buildStat('0', 'Today'),
                  _buildVerticalDivider(),
                  _buildStat('0', 'This Week'),
                  _buildVerticalDivider(),
                  _buildStat('0', 'Total'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Detection Log',
              style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            // Empty State
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 48,
                      color: AppColors.divider,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No detections yet',
                      style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Detected voices will appear here',
                      style: AppTypography.bodySmall(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.metadata(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.divider,
    );
  }
}
