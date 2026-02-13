// VIBRO Confidence Badge Widget
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

  Color _getBadgeColor() {
    final level = AppUtils.getConfidenceLevel(confidence);
    switch (level) {
      case 'high':
        return AppColors.confidenceHigh;
      case 'medium':
        return AppColors.confidenceMedium;
      case 'low':
        return AppColors.confidenceLow;
      default:
        return AppColors.steelBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getBadgeColor().withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        AppUtils.formatConfidence(confidence),
        style: AppTypography.confidenceBadge(
          color: AppColors.platinumWhite,
        ),
      ),
    );
  }
}
