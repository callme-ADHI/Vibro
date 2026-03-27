// VIBRO Subscription Page — Premium plan tiers with feature comparison
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  String _currentPlan = 'basic'; // basic / pro / enterprise

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Subscription Plans',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary)
              .copyWith(fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current plan badge
            _buildCurrentPlanBanner(),
            const SizedBox(height: 24),

            // Plan cards
            _buildPlanCard(
              planKey: 'basic',
              name: 'Basic',
              price: 'Free',
              period: '',
              description: 'Get started with essential voice recognition',
              features: [
                _PlanFeature('3 Voice Models', true),
                _PlanFeature('2 Location Profiles', true),
                _PlanFeature('Basic Detection', true),
                _PlanFeature('7-day History', true),
                _PlanFeature('Priority Training', false),
                _PlanFeature('Advanced Analytics', false),
                _PlanFeature('Custom Sensitivity', false),
              ],
              accentColor: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),

            _buildPlanCard(
              planKey: 'pro',
              name: 'Pro',
              price: '₹299',
              period: '/month',
              description: 'Enhanced features for daily use',
              features: [
                _PlanFeature('10 Voice Models', true),
                _PlanFeature('5 Location Profiles', true),
                _PlanFeature('Advanced Detection', true),
                _PlanFeature('30-day History', true),
                _PlanFeature('Priority Training', true),
                _PlanFeature('Advanced Analytics', true),
                _PlanFeature('Custom Sensitivity', true),
              ],
              accentColor: AppColors.accentNavy,
              isPopular: true,
            ),
            const SizedBox(height: 16),

            _buildPlanCard(
              planKey: 'enterprise',
              name: 'Enterprise',
              price: '₹799',
              period: '/month',
              description: 'Full suite for organizations & power users',
              features: [
                _PlanFeature('Unlimited Voice Models', true),
                _PlanFeature('Unlimited Locations', true),
                _PlanFeature('Real-time Detection', true),
                _PlanFeature('Unlimited History', true),
                _PlanFeature('Priority Training', true),
                _PlanFeature('Advanced Analytics', true),
                _PlanFeature('Custom Sensitivity', true),
                _PlanFeature('Dedicated Support', true),
                _PlanFeature('API Access', true),
              ],
              accentColor: AppColors.primaryNavy,
            ),

            const SizedBox(height: 32),

            // Footer info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.badgeBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.accentNavy, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'All plans include core vibration alerts from your ESP32 device. Upgrade anytime — no contracts.',
                      style: AppTypography.metadata(color: AppColors.accentNavy),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ───── Current Plan Banner ─────

  Widget _buildCurrentPlanBanner() {
    final planName = _currentPlan == 'basic'
        ? 'Basic'
        : _currentPlan == 'pro'
            ? 'Pro'
            : 'Enterprise';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryNavy,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: AppColors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Plan',
                  style: AppTypography.metadata(color: AppColors.white)
                      .copyWith(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  planName,
                  style: AppTypography.sectionTitle(color: AppColors.white)
                      .copyWith(fontSize: 20),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'ACTIVE',
              style: AppTypography.metadata(color: AppColors.white).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───── Plan Card ─────

  Widget _buildPlanCard({
    required String planKey,
    required String name,
    required String price,
    required String period,
    required String description,
    required List<_PlanFeature> features,
    required Color accentColor,
    bool isPopular = false,
  }) {
    final isCurrentPlan = _currentPlan == planKey;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentPlan
              ? AppColors.primaryNavy
              : isPopular
                  ? AppColors.accentNavy.withValues(alpha: 0.4)
                  : AppColors.divider,
          width: isCurrentPlan || isPopular ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Popular badge
          if (isPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentNavy,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Text(
                  '★  MOST POPULAR',
                  style: AppTypography.metadata(color: AppColors.white).copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    fontSize: 11,
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      name,
                      style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                          .copyWith(fontSize: 20),
                    ),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          price,
                          style: AppTypography.pageTitle(color: accentColor)
                              .copyWith(fontSize: 28, fontWeight: FontWeight.w700),
                        ),
                        if (period.isNotEmpty)
                          Text(
                            period,
                            style: AppTypography.bodySmall(
                                    color: AppColors.textSecondary)
                                .copyWith(fontSize: 13),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bodySmall(color: AppColors.textSecondary),
                ),

                const SizedBox(height: 16),
                Container(height: 1, color: AppColors.divider),
                const SizedBox(height: 16),

                // Features
                ...features.map((f) => _buildFeatureRow(f)),

                const SizedBox(height: 16),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: isCurrentPlan
                      ? OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppColors.divider, width: 1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            'Current Plan',
                            style: AppTypography.bodyMedium(
                                    color: AppColors.textSecondary)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        )
                      : ElevatedButton(
                          onPressed: () {
                            _showUpgradeDialog(name);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: AppColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                            planKey == 'basic' ? 'Downgrade' : 'Upgrade',
                            style: AppTypography.bodyMedium(
                                    color: AppColors.white)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(_PlanFeature feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            feature.included
                ? Icons.check_circle_rounded
                : Icons.cancel_rounded,
            color:
                feature.included ? AppColors.success : AppColors.divider,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            feature.name,
            style: AppTypography.bodySmall(
              color: feature.included
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ).copyWith(
              fontWeight: feature.included ? FontWeight.w500 : FontWeight.w400,
              decoration: feature.included ? null : TextDecoration.lineThrough,
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(String planName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Upgrade to $planName',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary)
              .copyWith(fontSize: 18),
        ),
        content: Text(
          'Subscription upgrades will be available soon. Stay tuned for premium features!',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Got It',
              style: AppTypography.bodyMedium(color: AppColors.primaryNavy)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ───── Plan Feature Data ─────

class _PlanFeature {
  final String name;
  final bool included;

  const _PlanFeature(this.name, this.included);
}
