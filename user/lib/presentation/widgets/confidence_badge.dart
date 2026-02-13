// VIBRO Confidence Badge Widget — White & Navy Enterprise
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/app_utils.dart';

class ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const ConfidenceBadge({
    super.key,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.badgeBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppUtils.formatConfidence(confidence),
        style: AppTypography.confidenceBadge(
          color: AppColors.primaryNavy,
        ),
      ),
    );
  }
}
