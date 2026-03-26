import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class ConnectedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const ConnectedBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard'),
              _buildNavItem(1, Icons.group_outlined, Icons.group_rounded, 'Connect'),
              _buildNavItem(2, Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Logs'),
              _buildNavItem(3, Icons.account_circle_outlined, Icons.account_circle_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : icon, color: isActive ? AppColors.primaryNavy : AppColors.textSecondary, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.metadata(color: isActive ? AppColors.primaryNavy : AppColors.textSecondary)
                  .copyWith(fontWeight: isActive ? FontWeight.w600 : FontWeight.w500, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
