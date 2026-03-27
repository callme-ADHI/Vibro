import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class ConnectivityPage extends StatelessWidget {
  const ConnectivityPage({super.key});

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
          'Connectivity',
          style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.badgeBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.sensors_rounded, size: 32, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 24),
            Text(
              'Connectivity',
              style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Hardware connectivity settings will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
