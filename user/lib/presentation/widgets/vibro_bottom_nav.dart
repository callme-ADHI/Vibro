// VIBRO Bottom Navigation Bar — Medical-Grade Enterprise
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Custom bottom navigation bar for VIBRO
/// 5 tabs: Home, Names, Listening (center elevated), History, Settings
class VibroBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isListening;

  const VibroBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isListening = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Home',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.subtitles_outlined, // Was index 3
                activeIcon: Icons.subtitles_rounded,
                label: 'Captions', // Was index 3
              ),
              _buildCenterButton(), // Index 2
              _buildNavItem(
                index: 3,
                icon: Icons.person_outline_rounded, // Was index 1
                activeIcon: Icons.person_rounded,
                label: 'Models', // Was index 1 (Names)
              ),
              _buildNavItem(
                index: 4,
                icon: Icons.sensors_outlined, // Was settings
                activeIcon: Icons.sensors_rounded,
                label: 'Connectivity', // Was settings
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final bool isActive = currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        height: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Active indicator line
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: isActive ? 24 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(height: 6),
            // Icon
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.primaryNavy : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              label,
              style: AppTypography.metadata(
                color: isActive ? AppColors.primaryNavy : AppColors.textSecondary,
              ).copyWith(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    final bool isActive = currentIndex == 2;

    // Mic button color based on state
    Color buttonColor = AppColors.primaryNavy;
    IconData micIcon = Icons.mic_rounded;

    return GestureDetector(
      onTap: () => onTap(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryNavy.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                micIcon,
                color: AppColors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Listen',
            style: AppTypography.metadata(
              color: isActive ? AppColors.primaryNavy : AppColors.textSecondary,
            ).copyWith(
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
