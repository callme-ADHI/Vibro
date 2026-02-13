// VIBRO Training Status Page — 4-state training lifecycle UI
import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/training_service.dart';

class TrainingStatusPage extends StatefulWidget {
  const TrainingStatusPage({super.key});

  @override
  State<TrainingStatusPage> createState() => _TrainingStatusPageState();
}

class _TrainingStatusPageState extends State<TrainingStatusPage>
    with SingleTickerProviderStateMixin {
  TrainingStatusData? _statusData;
  TrainingStatus _currentStatus = TrainingStatus.notStarted;
  int _progress = 0;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isDownloadingModel = false;
  int? _modelVersion;

  StreamSubscription<TrainingStatusData>? _subscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadStatus();
    _subscribeToUpdates();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController.dispose();
    TrainingService.instance.unsubscribe();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final status = await TrainingService.instance.getCurrentStatus();
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (status != null) {
          _statusData = status;
          _currentStatus = status.status;
          _progress = status.progressPercentage;
          _errorMessage = status.errorMessage;
          _modelVersion = status.modelVersion;
        }
      });

      // Auto-download model if completed
      if (_currentStatus == TrainingStatus.completed) {
        _checkAndDownloadModel();
      }
    }
  }

  void _subscribeToUpdates() {
    final stream = TrainingService.instance.subscribeToStatus();
    _subscription = stream.listen((data) {
      if (mounted) {
        setState(() {
          _statusData = data;
          _currentStatus = data.status;
          _progress = data.progressPercentage;
          _errorMessage = data.errorMessage;
          _modelVersion = data.modelVersion;
        });

        if (data.status == TrainingStatus.completed) {
          _checkAndDownloadModel();
        }
      }
    });
  }

  Future<void> _checkAndDownloadModel() async {
    setState(() => _isDownloadingModel = true);

    try {
      final downloaded = await TrainingService.instance.downloadModelIfNeeded();
      if (mounted) {
        setState(() => _isDownloadingModel = false);
        if (downloaded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Model updated successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloadingModel = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Model download failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Model Training',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  if (_currentStatus.isInProgress) _buildProgressSection(),
                  if (_currentStatus == TrainingStatus.completed) _buildCompletedSection(),
                  if (_currentStatus == TrainingStatus.failed) _buildFailedSection(),
                  if (_currentStatus == TrainingStatus.notStarted) _buildNotStartedSection(),
                ],
              ),
            ),
    );
  }

  // ─────── Status Card ───────

  Widget _buildStatusCard() {
    final Color statusColor;
    final IconData statusIcon;

    switch (_currentStatus) {
      case TrainingStatus.notStarted:
        statusColor = AppColors.textSecondary;
        statusIcon = Icons.hourglass_empty_rounded;
        break;
      case TrainingStatus.downloadingAudio:
      case TrainingStatus.training:
      case TrainingStatus.uploadingModel:
        statusColor = AppColors.accentNavy;
        statusIcon = Icons.model_training_rounded;
        break;
      case TrainingStatus.completed:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case TrainingStatus.failed:
        statusColor = AppColors.error;
        statusIcon = Icons.error_rounded;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Status icon
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _currentStatus.isInProgress
                  ? 1.0 + (_pulseController.value * 0.1)
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 36),
            ),
          ),

          const SizedBox(height: 16),

          // Status text
          Text(
            _currentStatus.displayText,
            style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 20),
          ),

          if (_currentStatus.isInProgress) ...[
            const SizedBox(height: 8),
            Text(
              '$_progress%',
              style: AppTypography.pageTitle(color: statusColor).copyWith(fontSize: 28),
            ),
          ],

          if (_modelVersion != null && _currentStatus == TrainingStatus.completed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'v$_modelVersion',
                style: AppTypography.bodySmall(color: AppColors.white).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─────── In Progress Section ───────

  Widget _buildProgressSection() {
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
            'Training Progress',
            style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: AppColors.divider,
              color: AppColors.primaryNavy,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),

          // Steps
          _buildStepRow('Downloading audio', _progress >= 10, _currentStatus == TrainingStatus.downloadingAudio),
          _buildStepRow('Extracting features', _progress >= 40, _currentStatus == TrainingStatus.training && _progress < 50),
          _buildStepRow('Training model', _progress >= 50, _currentStatus == TrainingStatus.training && _progress >= 50),
          _buildStepRow('Converting to TFLite', _progress >= 85, _currentStatus == TrainingStatus.uploadingModel),
          _buildStepRow('Uploading model', _progress >= 90, false),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.badgeBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.accentNavy, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Training is running on the server. You can leave this page — it will continue in the background.',
                    style: AppTypography.metadata(color: AppColors.accentNavy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String label, bool completed, bool isCurrent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: completed
                  ? AppColors.success
                  : isCurrent
                      ? AppColors.accentNavy
                      : AppColors.divider,
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check_rounded : isCurrent ? Icons.more_horiz_rounded : Icons.circle,
              color: AppColors.white,
              size: 12,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: AppTypography.bodySmall(
              color: completed || isCurrent ? AppColors.textPrimary : AppColors.textSecondary,
            ).copyWith(fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400),
          ),
        ],
      ),
    );
  }

  // ─────── Completed Section ───────

  Widget _buildCompletedSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          if (_isDownloadingModel) ...[
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 12),
            Text(
              'Downloading trained model...',
              style: AppTypography.bodyMedium(color: AppColors.textSecondary),
            ),
          ] else ...[
            const Icon(Icons.download_done_rounded, color: AppColors.success, size: 28),
            const SizedBox(height: 12),
            Text(
              'Model is ready on your device',
              style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Voice detection will use the latest model',
              style: AppTypography.bodySmall(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  // ─────── Failed Section ───────

  Widget _buildFailedSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: AppTypography.bodySmall(color: AppColors.error),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Training failed. Contact support or try again.',
            style: AppTypography.bodyMedium(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () {
                // Retry — reset status for admin to re-run
                _retryTraining();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Request Retry',
                style: AppTypography.bodyMedium(color: AppColors.white).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retryTraining() async {
    if (_statusData?.trainedNameId == null) return;

    try {
      await TrainingService.instance.initializeTrainingStatus(_statusData!.trainedNameId);
      setState(() {
        _currentStatus = TrainingStatus.notStarted;
        _progress = 0;
        _errorMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Training status reset. Admin will start training soon.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─────── Not Started Section ───────

  Widget _buildNotStartedSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.badgeBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.model_training_rounded, color: AppColors.primaryNavy, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Model not trained yet',
            style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload voice samples in the Names tab, then your model will be trained by our team.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.badgeBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.accentNavy, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Training happens on our servers. You\'ll see live progress here once it starts.',
                    style: AppTypography.metadata(color: AppColors.accentNavy),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
