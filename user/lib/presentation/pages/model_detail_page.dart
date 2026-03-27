// VIBRO Model Detail Page — Delivery-style training timeline with timestamps
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/training_service.dart';

class ModelDetailPage extends StatefulWidget {
  final String nameId;
  final String nameLabel;
  final int clipCount;
  final String audioStatus; // 'No Samples', 'Ready', 'Training', 'Trained', 'Failed'

  const ModelDetailPage({
    super.key,
    required this.nameId,
    required this.nameLabel,
    this.clipCount = 0,
    this.audioStatus = 'No Samples',
  });

  @override
  State<ModelDetailPage> createState() => _ModelDetailPageState();
}

class _ModelDetailPageState extends State<ModelDetailPage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  TrainingStatusData? _statusData;
  Map<String, dynamic>? _audioSubmission;
  late AnimationController _pulseController;
  StreamSubscription<TrainingStatusData>? _subscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Fetch training status for this specific name
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final statusResponse = await Supabase.instance.client
          .from('user_training_status')
          .select()
          .eq('user_id', userId)
          .eq('trained_name_id', widget.nameId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // Fetch audio submission
      final audioResponse = await Supabase.instance.client
          .from('audio_submissions')
          .select()
          .eq('trained_name_id', widget.nameId)
          .eq('user_id', userId)
          .order('uploaded_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _isLoading = false;
          if (statusResponse != null) {
            _statusData = TrainingStatusData.fromJson(statusResponse);
          }
          _audioSubmission = audioResponse;
        });
      }

      // Subscribe to realtime updates for this name's training
      _subscribeToUpdates(userId);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToUpdates(String userId) {
    final channel = Supabase.instance.client
        .channel('model_detail_${widget.nameId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_training_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trained_name_id',
            value: widget.nameId,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            if (data.isNotEmpty && mounted) {
              setState(() {
                _statusData = TrainingStatusData.fromJson(data);
              });
            }
          },
        )
        .subscribe();
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.nameLabel,
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModelHeader(),
                  const SizedBox(height: 24),
                  Text(
                    'Training Timeline',
                    style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                        .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  _buildTimeline(),
                  const SizedBox(height: 24),
                  if (_statusData != null && _statusData!.status == TrainingStatus.completed)
                    _buildModelInfoCard(),
                  if (_statusData != null && _statusData!.status == TrainingStatus.failed)
                    _buildFailedCard(),
                ],
              ),
            ),
    );
  }

  // ───── Header Card ─────

  Widget _buildModelHeader() {
    final status = _statusData?.status ?? TrainingStatus.notStarted;
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    switch (status) {
      case TrainingStatus.notStarted:
        statusColor = AppColors.textSecondary;
        statusText = widget.audioStatus == 'No Samples' ? 'Awaiting Samples' : 'Queued for Training';
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case TrainingStatus.downloadingAudio:
      case TrainingStatus.training:
      case TrainingStatus.uploadingModel:
        statusColor = AppColors.accentNavy;
        statusText = status.displayText;
        statusIcon = Icons.model_training_rounded;
        break;
      case TrainingStatus.completed:
        statusColor = AppColors.success;
        statusText = 'Model Ready';
        statusIcon = Icons.check_circle_rounded;
        break;
      case TrainingStatus.failed:
        statusColor = AppColors.error;
        statusText = 'Training Failed';
        statusIcon = Icons.error_rounded;
        break;
    }

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
          // Animated icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = status.isInProgress
                  ? 1.0 + (_pulseController.value * 0.08)
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(statusIcon, color: statusColor, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nameLabel,
                  style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                      .copyWith(fontSize: 18),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(statusText,
                        style: AppTypography.bodySmall(color: statusColor)
                            .copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
                if (status.isInProgress && _statusData != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _statusData!.progressPercentage / 100,
                      backgroundColor: AppColors.divider,
                      color: AppColors.primaryNavy,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_statusData!.progressPercentage}% complete',
                    style: AppTypography.metadata(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───── Timeline ─────

  Widget _buildTimeline() {
    final status = _statusData?.status ?? TrainingStatus.notStarted;
    final progress = _statusData?.progressPercentage ?? 0;
    final uploadedAt = _audioSubmission?['uploaded_at'] as String?;
    final updatedAt = _statusData?.updatedAt;

    // Timeline steps (delivery-style)
    final steps = <_TimelineStep>[
      _TimelineStep(
        title: 'Name Registered',
        subtitle: 'Voice identity created in the system',
        timestamp: _formatTimestamp(null), // We don't have this separately, use created
        isCompleted: true, // Always true if we're on this page
        icon: Icons.person_add_rounded,
      ),
      _TimelineStep(
        title: 'Audio Samples Uploaded',
        subtitle: '${widget.clipCount} voice clips submitted',
        timestamp: uploadedAt != null ? _formatTimestamp(uploadedAt) : null,
        isCompleted: widget.audioStatus != 'No Samples',
        isCurrent: widget.audioStatus == 'No Samples',
        icon: Icons.mic_rounded,
      ),
      _TimelineStep(
        title: 'Preparing Audio',
        subtitle: 'Downloading and pre-processing samples',
        timestamp: status == TrainingStatus.downloadingAudio || _isStatusPast(status, TrainingStatus.downloadingAudio)
            ? _formatTimestamp(updatedAt?.toIso8601String())
            : null,
        isCompleted: _isStatusPast(status, TrainingStatus.downloadingAudio),
        isCurrent: status == TrainingStatus.downloadingAudio,
        icon: Icons.cloud_download_rounded,
      ),
      _TimelineStep(
        title: 'Training Model',
        subtitle: 'AI is learning to recognize this voice',
        timestamp: status == TrainingStatus.training || _isStatusPast(status, TrainingStatus.training)
            ? _formatTimestamp(updatedAt?.toIso8601String())
            : null,
        isCompleted: _isStatusPast(status, TrainingStatus.training),
        isCurrent: status == TrainingStatus.training,
        icon: Icons.model_training_rounded,
        progressValue: status == TrainingStatus.training ? progress / 100 : null,
      ),
      _TimelineStep(
        title: 'Finalizing Model',
        subtitle: 'Converting and uploading trained model',
        timestamp: status == TrainingStatus.uploadingModel || _isStatusPast(status, TrainingStatus.uploadingModel)
            ? _formatTimestamp(updatedAt?.toIso8601String())
            : null,
        isCompleted: _isStatusPast(status, TrainingStatus.uploadingModel),
        isCurrent: status == TrainingStatus.uploadingModel,
        icon: Icons.cloud_upload_rounded,
      ),
      _TimelineStep(
        title: 'Model Ready',
        subtitle: status == TrainingStatus.completed
            ? 'Voice model deployed and active'
            : 'Waiting for earlier steps',
        timestamp: status == TrainingStatus.completed
            ? _formatTimestamp(updatedAt?.toIso8601String())
            : null,
        isCompleted: status == TrainingStatus.completed,
        isCurrent: false,
        icon: Icons.check_circle_rounded,
      ),
    ];

    return Column(
      children: List.generate(steps.length, (index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;
        return _buildTimelineItem(step, isLast);
      }),
    );
  }

  bool _isStatusPast(TrainingStatus current, TrainingStatus check) {
    const order = [
      TrainingStatus.notStarted,
      TrainingStatus.downloadingAudio,
      TrainingStatus.training,
      TrainingStatus.uploadingModel,
      TrainingStatus.completed,
    ];
    final currentIdx = order.indexOf(current);
    final checkIdx = order.indexOf(check);
    if (current == TrainingStatus.failed) {
      // If failed, everything up to training is "past"
      return checkIdx <= 2;
    }
    return currentIdx > checkIdx;
  }

  Widget _buildTimelineItem(_TimelineStep step, bool isLast) {
    final Color dotColor;
    final Color lineColor;

    if (step.isCompleted) {
      dotColor = AppColors.success;
      lineColor = AppColors.success;
    } else if (step.isCurrent) {
      dotColor = AppColors.accentNavy;
      lineColor = AppColors.divider;
    } else {
      dotColor = AppColors.divider;
      lineColor = AppColors.divider;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Dot
                Container(
                  width: step.isCurrent ? 20 : 16,
                  height: step.isCurrent ? 20 : 16,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: step.isCurrent
                        ? Border.all(
                            color: AppColors.accentNavy.withValues(alpha: 0.3),
                            width: 3)
                        : null,
                    boxShadow: step.isCurrent
                        ? [
                            BoxShadow(
                              color: AppColors.accentNavy.withValues(alpha: 0.2),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: Icon(
                    step.isCompleted
                        ? Icons.check_rounded
                        : step.isCurrent
                            ? Icons.more_horiz_rounded
                            : Icons.circle,
                    color: AppColors.white,
                    size: step.isCurrent ? 12 : 10,
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: step.isCurrent
                    ? AppColors.accentNavy.withValues(alpha: 0.04)
                    : AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: step.isCurrent ? AppColors.accentNavy.withValues(alpha: 0.2) : AppColors.divider,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(step.icon,
                          size: 18,
                          color: step.isCompleted
                              ? AppColors.success
                              : step.isCurrent
                                  ? AppColors.accentNavy
                                  : AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.title,
                          style: AppTypography.bodyMedium(
                            color: step.isCompleted || step.isCurrent
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ).copyWith(
                            fontWeight: step.isCurrent ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 26),
                    child: Text(
                      step.subtitle,
                      style: AppTypography.metadata(color: AppColors.textSecondary),
                    ),
                  ),
                  if (step.timestamp != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            step.timestamp!,
                            style: AppTypography.metadata(color: AppColors.textSecondary)
                                .copyWith(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (step.progressValue != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 26),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: step.progressValue!,
                          backgroundColor: AppColors.divider,
                          color: AppColors.accentNavy,
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───── Model Info Card ─────

  Widget _buildModelInfoCard() {
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
          Text(
            'Model Details',
            style: AppTypography.bodyMedium(color: AppColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          if (_statusData!.modelVersion != null)
            _buildInfoRow('Version', 'v${_statusData!.modelVersion}'),
          if (_statusData!.accuracyMetric != null) ...[
            const Divider(color: AppColors.divider, height: 20),
            _buildInfoRow(
              'Accuracy',
              '${(_statusData!.accuracyMetric! * 100).toStringAsFixed(1)}%',
              valueColor: AppColors.success,
            ),
          ],
          const Divider(color: AppColors.divider, height: 20),
          _buildInfoRow('Samples', '${widget.clipCount} clips'),
          const Divider(color: AppColors.divider, height: 20),
          _buildInfoRow('Last Updated', _formatTimestamp(_statusData!.updatedAt.toIso8601String()) ?? '—'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTypography.bodySmall(color: AppColors.textSecondary)),
        Text(value,
            style: AppTypography.bodyMedium(
                    color: valueColor ?? AppColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ───── Failed Card ─────

  Widget _buildFailedCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFEE2E2)),
      ),
      child: Column(
        children: [
          if (_statusData!.errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _statusData!.errorMessage!,
                style: AppTypography.bodySmall(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Training failed. Please contact support or try again.',
            style: AppTypography.bodyMedium(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ───── Helpers ─────

  String? _formatTimestamp(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final detDate = DateTime(dt.year, dt.month, dt.day);

      final time =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

      if (detDate == today) return 'Today at $time';
      final yesterday = today.subtract(const Duration(days: 1));
      if (detDate == yesterday) return 'Yesterday at $time';

      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $time';
    } catch (_) {
      return null;
    }
  }
}

// ───── Data class for timeline steps ─────

class _TimelineStep {
  final String title;
  final String subtitle;
  final String? timestamp;
  final bool isCompleted;
  final bool isCurrent;
  final IconData icon;
  final double? progressValue;

  const _TimelineStep({
    required this.title,
    required this.subtitle,
    this.timestamp,
    this.isCompleted = false,
    this.isCurrent = false,
    required this.icon,
    this.progressValue,
  });
}
