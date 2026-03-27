// VIBRO Detection Log Page — Detailed detection history with accuracy analytics
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/history_service.dart';

class DetectionLogPage extends StatefulWidget {
  const DetectionLogPage({super.key});

  @override
  State<DetectionLogPage> createState() => _DetectionLogPageState();
}

class _DetectionLogPageState extends State<DetectionLogPage> {
  final HistoryService _historyService = HistoryService.instance;

  Map<String, int> _stats = {'today': 0, 'week': 0, 'total': 0};
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String? _error;

  // Accuracy distribution
  int _highCount = 0;
  int _mediumCount = 0;
  int _lowCount = 0;
  double _avgAccuracy = 0.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _historyService.getStats();
      final items = await _historyService.getHistory(limit: 200);

      // Calculate accuracy distribution
      int high = 0, medium = 0, low = 0;
      double totalAcc = 0;
      for (final item in items) {
        final acc = (item['accuracy'] as num?)?.toDouble() ?? 0.0;
        totalAcc += acc;
        if (acc >= 0.8) {
          high++;
        } else if (acc >= 0.6) {
          medium++;
        } else {
          low++;
        }
      }

      if (mounted) {
        setState(() {
          _stats = stats;
          _items = items;
          _highCount = high;
          _mediumCount = medium;
          _lowCount = low;
          _avgAccuracy = items.isNotEmpty ? totalAcc / items.length : 0.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final detDate = DateTime(dt.year, dt.month, dt.day);

      final time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      if (detDate == today) {
        return 'Today $time';
      }
      final yesterday = today.subtract(const Duration(days: 1));
      if (detDate == yesterday) {
        return 'Yesterday $time';
      }
      if (now.difference(dt).inDays < 7) {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return '${days[dt.weekday - 1]} $time';
      }
      return '${dt.day}/${dt.month}/${dt.year % 100}  $time';
    } catch (_) {
      return '—';
    }
  }

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
          'Detection Log',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary)
              .copyWith(fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryNavy))
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primaryNavy,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(),
                        const SizedBox(height: 20),
                        _buildAccuracyCard(),
                        const SizedBox(height: 24),
                        Text(
                          'Detection Timeline',
                          style: AppTypography.sectionTitle(
                                  color: AppColors.textPrimary)
                              .copyWith(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        _items.isEmpty ? _buildEmpty() : _buildTimeline(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    AppTypography.bodyMedium(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ──────── Stats Row ────────

  Widget _buildStatsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _buildStat('${_stats['today'] ?? 0}', 'Today'),
          _buildVerticalDivider(),
          _buildStat('${_stats['week'] ?? 0}', 'This Week'),
          _buildVerticalDivider(),
          _buildStat('${_stats['total'] ?? 0}', 'Total'),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                .copyWith(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.metadata(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 36, color: AppColors.divider);
  }

  // ──────── Accuracy Analytics Card ────────

  Widget _buildAccuracyCard() {
    final total = _highCount + _mediumCount + _lowCount;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Accuracy Overview',
                style:
                    AppTypography.bodyMedium(color: AppColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _avgAccuracyColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Avg: ${(_avgAccuracy * 100).toStringAsFixed(1)}%',
                  style: AppTypography.metadata(color: _avgAccuracyColor())
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Accuracy bar
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (_highCount > 0)
                      Flexible(
                        flex: _highCount,
                        child: Container(color: AppColors.success),
                      ),
                    if (_mediumCount > 0)
                      Flexible(
                        flex: _mediumCount,
                        child: Container(color: AppColors.accentNavy),
                      ),
                    if (_lowCount > 0)
                      Flexible(
                        flex: _lowCount,
                        child: Container(color: AppColors.warning),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Legend
          Row(
            children: [
              _buildLegendItem(AppColors.success, 'High (≥80%)', _highCount, total),
              const SizedBox(width: 16),
              _buildLegendItem(AppColors.accentNavy, 'Medium (≥60%)', _mediumCount, total),
              const SizedBox(width: 16),
              _buildLegendItem(AppColors.warning, 'Low (<60%)', _lowCount, total),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, int count, int total) {
    final pct = total > 0 ? ((count / total) * 100).round() : 0;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: AppTypography.metadata(color: AppColors.textSecondary)
                        .copyWith(fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(
              '$count ($pct%)',
              style: AppTypography.bodySmall(color: AppColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _avgAccuracyColor() {
    if (_avgAccuracy >= 0.8) return AppColors.success;
    if (_avgAccuracy >= 0.6) return AppColors.accentNavy;
    return AppColors.warning;
  }

  // ──────── Empty State ────────

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 48,
              color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No detections yet',
              style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text(
            'Detections will show up here once your model starts recognizing voices.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ──────── Timeline ────────

  Widget _buildTimeline() {
    return Column(
      children: List.generate(_items.length, (index) {
        final item = _items[index];
        final name = item['name_label'] as String? ?? '—';
        final location = item['location_name'] as String?;
        final accuracy = (item['accuracy'] as num?)?.toDouble() ?? 0.0;
        final detectedAt = item['detected_at'] as String?;
        final confPercent = (accuracy * 100).toStringAsFixed(1);
        final isLast = index == _items.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line + dot
              SizedBox(
                width: 32,
                child: Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _confidenceColor(accuracy),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _confidenceColor(accuracy).withValues(alpha: 0.3),
                          width: 3,
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.divider,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Card
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryNavy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style:
                                AppTypography.sectionTitle(color: AppColors.primaryNavy)
                                    .copyWith(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTypography.bodyMedium(
                                      color: AppColors.textPrimary)
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              location != null && location.isNotEmpty
                                  ? '${_formatTime(detectedAt)}  •  $location'
                                  : _formatTime(detectedAt),
                              style: AppTypography.metadata(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      // Accuracy badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _confidenceColor(accuracy)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$confPercent%',
                          style: AppTypography.bodySmall(
                                  color: _confidenceColor(accuracy))
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 0.8) return AppColors.success;
    if (confidence >= 0.6) return AppColors.accentNavy;
    return AppColors.warning;
  }
}
