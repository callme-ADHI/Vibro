// VIBRO Names Page — Manage trained voice names
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class NamesPage extends StatelessWidget {
  const NamesPage({super.key});

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
          'Names',
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
            // Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.badgeBackground,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: AppColors.primaryNavy,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Training',
                              style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Train Vibro to recognize specific voices',
                              style: AppTypography.bodySmall(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Trained Names',
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
                      Icons.person_outline_rounded,
                      size: 48,
                      color: AppColors.divider,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No voices trained yet',
                      style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add a name to start voice training',
                      style: AppTypography.bodySmall(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: Text(
                          'Add Name',
                          style: AppTypography.bodyMedium(color: AppColors.white).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryNavy,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
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
}
