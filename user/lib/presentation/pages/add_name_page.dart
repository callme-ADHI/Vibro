// VIBRO Add Name Page — 3-Step Flow: Name Input → Voice Recording → Upload
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/name_service.dart';
import '../../core/services/audio_recording_service.dart';

class AddNamePage extends StatefulWidget {
  const AddNamePage({super.key});

  @override
  State<AddNamePage> createState() => _AddNamePageState();
}

class _AddNamePageState extends State<AddNamePage> {
  // Step tracking
  int _currentStep = 0; // 0: Name, 1: Recording, 2: Uploading

  // Step 1 — Name Input
  final TextEditingController _nameController = TextEditingController();
  String? _nameError;
  bool _isCheckingName = false;

  // Step 2 — Recording
  final int _requiredSamples = 10;
  int _completedSamples = 0;
  final List<String> _recordedPaths = [];
  bool _isRecording = false;
  Timer? _recordTimer;
  double _recordProgress = 0;

  // Step 3 — Upload
  bool _isUploading = false;
  String? _uploadError;
  String? _createdNameId;

  @override
  void dispose() {
    _nameController.dispose();
    _recordTimer?.cancel();
    AudioRecordingService.instance.cleanupTempFiles();
    super.dispose();
  }

  // ─────────── Step 1: Name Validation ───────────

  Future<void> _validateName(String value) async {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() => _nameError = null);
      return;
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed)) {
      setState(() => _nameError = 'Only alphabetic characters allowed');
      return;
    }

    if (trimmed.length > 20) {
      setState(() => _nameError = 'Maximum 20 characters');
      return;
    }

    setState(() {
      _isCheckingName = true;
      _nameError = null;
    });

    try {
      final exists = await NameService.instance.nameExists(trimmed);
      if (mounted) {
        setState(() {
          _isCheckingName = false;
          _nameError = exists ? 'This name already exists' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingName = false;
          _nameError = 'Could not validate name';
        });
      }
    }
  }

  bool get _isNameValid {
    final trimmed = _nameController.text.trim();
    return trimmed.isNotEmpty &&
        trimmed.length <= 20 &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(trimmed) &&
        _nameError == null &&
        !_isCheckingName;
  }

  Future<void> _proceedToRecording() async {
    if (!_isNameValid) return;

    try {
      // Create the name entry first
      final record = await NameService.instance.createName(_nameController.text.trim());
      _createdNameId = record['id'];

      // Check mic permission
      final hasMic = await AudioRecordingService.instance.ensureMicPermission();
      if (!hasMic) {
        if (mounted) {
          _showMicPermissionDialog();
        }
        return;
      }

      setState(() => _currentStep = 1);
    } catch (e) {
      if (mounted) {
        setState(() => _nameError = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _showMicPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Microphone Required',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
        ),
        content: Text(
          'Microphone access is required to record voice samples. Please enable it in your device settings.',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: Text(
              'Open Settings',
              style: AppTypography.bodyMedium(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── Step 2: Recording ───────────

  Future<void> _startRecording() async {
    if (_isRecording || _completedSamples >= _requiredSamples) return;

    try {
      await AudioRecordingService.instance.startRecording(_completedSamples);
      setState(() {
        _isRecording = true;
        _recordProgress = 0;
      });

      // Auto-stop after 2 seconds with progress updates
      _recordTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _recordProgress += 0.05 / 2; // 50ms / 2000ms
        });
        if (_recordProgress >= 1.0) {
          timer.cancel();
          _stopRecording();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recording failed: ${e.toString().replaceFirst("Exception: ", "")}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();

    final path = await AudioRecordingService.instance.stopRecording();
    if (path != null && mounted) {
      setState(() {
        _isRecording = false;
        _recordedPaths.add(path);
        _completedSamples++;
        _recordProgress = 0;
      });
    }
  }

  Future<void> _reRecordLast() async {
    if (_completedSamples <= 0 || _isRecording) return;
    setState(() {
      _completedSamples--;
      _recordedPaths.removeLast();
    });
  }

  // ─────────── Step 3: Upload ───────────

  Future<void> _uploadSamples() async {
    if (_createdNameId == null) return;

    setState(() {
      _currentStep = 2;
      _isUploading = true;
      _uploadError = null;
    });

    try {
      await AudioRecordingService.instance.uploadSamples(
        nameId: _createdNameId!,
        sampleCount: _completedSamples,
      );

      await AudioRecordingService.instance.cleanupTempFiles();

      if (mounted) {
        setState(() => _isUploading = false);
        // Brief success display then pop
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  // ─────────── BUILD ───────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
          onPressed: () => _confirmExit(),
        ),
        title: Text(
          _currentStep == 0
              ? 'Add New Name'
              : _currentStep == 1
                  ? 'Record Samples'
                  : 'Uploading',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _currentStep == 0
            ? _buildNameInputStep()
            : _currentStep == 1
                ? _buildRecordingStep()
                : _buildUploadStep(),
      ),
    );
  }

  void _confirmExit() {
    if (_currentStep == 0 && _nameController.text.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Discard Progress?',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
        ),
        content: Text(
          'Your recordings will be lost if you leave now.',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Stay', style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // If name was created but no upload, delete it
              if (_createdNameId != null) {
                NameService.instance.deleteName(_createdNameId!);
              }
              AudioRecordingService.instance.cleanupTempFiles();
              Navigator.of(context).pop();
            },
            child: Text(
              'Discard',
              style: AppTypography.bodyMedium(color: AppColors.error).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── Step 1 UI: Name Input ───────────

  Widget _buildNameInputStep() {
    return SingleChildScrollView(
      key: const ValueKey('step_name'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Instruction
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
                      child: const Icon(Icons.person_add_rounded, color: AppColors.primaryNavy, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Enter the name you want Vibro to recognize',
                        style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Name Field
          Text(
            'Name',
            style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          TextField(
            controller: _nameController,
            maxLength: 20,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
            ],
            onChanged: _validateName,
            style: AppTypography.bodyLarge(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Dad',
              hintStyle: AppTypography.bodyLarge(color: AppColors.textSecondary).copyWith(
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
              filled: true,
              fillColor: AppColors.white,
              counterText: '',
              errorText: _nameError,
              errorStyle: AppTypography.bodySmall(color: AppColors.error),
              suffixIcon: _isCheckingName
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentNavy,
                        ),
                      ),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accentNavy, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.error, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Only letters, max 20 characters',
            style: AppTypography.metadata(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 32),

          // Continue Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isNameValid ? _proceedToRecording : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.divider,
                disabledForegroundColor: AppColors.textSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Continue',
                style: AppTypography.bodyMedium(
                  color: _isNameValid ? AppColors.white : AppColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── Step 2 UI: Voice Recording ───────────

  Widget _buildRecordingStep() {
    final allDone = _completedSamples >= _requiredSamples;

    return SingleChildScrollView(
      key: const ValueKey('step_record'),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 8),

          // Name Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryNavy,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _nameController.text.trim().toUpperCase(),
              style: AppTypography.bodyMedium(color: AppColors.white).copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Record 10 clear samples',
            style: AppTypography.bodyMedium(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 28),

          // Sample Counter
          Text(
            '$_completedSamples/$_requiredSamples',
            style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 36),
          ),
          const SizedBox(height: 4),
          Text(
            'samples recorded',
            style: AppTypography.metadata(color: AppColors.textSecondary),
          ),

          const SizedBox(height: 32),

          // Record Button
          GestureDetector(
            onTap: allDone ? null : (_isRecording ? null : _startRecording),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress ring
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: _isRecording ? _recordProgress : 0,
                    strokeWidth: 3,
                    backgroundColor: AppColors.divider,
                    color: _isRecording ? AppColors.error : AppColors.primaryNavy,
                  ),
                ),
                // Button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: allDone
                        ? AppColors.success
                        : _isRecording
                            ? AppColors.error
                            : AppColors.primaryNavy,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      allDone
                          ? Icons.check_rounded
                          : _isRecording
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                      color: AppColors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Text(
            _isRecording
                ? 'Recording...'
                : allDone
                    ? 'All samples recorded'
                    : 'Tap to record',
            style: AppTypography.bodyMedium(
              color: _isRecording ? AppColors.error : AppColors.textSecondary,
            ).copyWith(fontWeight: FontWeight.w500),
          ),

          const SizedBox(height: 32),

          // Sample indicators
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_requiredSamples, (index) {
                final isCompleted = index < _completedSamples;
                final isCurrent = index == _completedSamples && _isRecording;

                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withOpacity(0.1)
                        : isCurrent
                            ? AppColors.error.withOpacity(0.1)
                            : AppColors.lightSurface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isCompleted
                          ? AppColors.success
                          : isCurrent
                              ? AppColors.error
                              : AppColors.divider,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check_rounded, color: AppColors.success, size: 18)
                        : isCurrent
                            ? const Icon(Icons.mic_rounded, color: AppColors.error, size: 18)
                            : Text(
                                '${index + 1}',
                                style: AppTypography.metadata(color: AppColors.textSecondary),
                              ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Re-record button
          if (_completedSamples > 0 && !_isRecording && !allDone)
            TextButton.icon(
              onPressed: _reRecordLast,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Re-record last sample',
                style: AppTypography.bodySmall(color: AppColors.accentNavy).copyWith(fontWeight: FontWeight.w500),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.accentNavy),
            ),

          const SizedBox(height: 24),

          // Save & Upload Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: allDone ? _uploadSamples : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.divider,
                disabledForegroundColor: AppColors.textSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Save & Upload',
                style: AppTypography.bodyMedium(
                  color: allDone ? AppColors.white : AppColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────── Step 3 UI: Upload Status ───────────

  Widget _buildUploadStep() {
    return Center(
      key: const ValueKey('step_upload'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isUploading) ...[
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primaryNavy,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Uploading samples...',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait while your voice samples are securely uploaded',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(color: AppColors.textSecondary),
              ),
            ] else if (_uploadError != null) ...[
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                'Upload Failed',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _uploadError!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _uploadSamples,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'Retry Upload',
                    style: AppTypography.bodyMedium(color: AppColors.white).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ] else ...[
              // Success
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 32),
              ),
              const SizedBox(height: 24),
              Text(
                'Upload Complete',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                '${_nameController.text.trim()} is ready for training',
                style: AppTypography.bodyMedium(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
