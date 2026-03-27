// VIBRO Add Name Page — Enhanced: 10+ samples, playback, delete individual
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/name_service.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/training_service.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final int _minSamples = 10;
  final List<VoiceSample> _samples = [];
  bool _isRecording = false;
  Timer? _recordTimer;
  double _recordProgress = 0;
  int _nextIndex = 0;

  // Playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  int? _playingIndex; // index of sample currently playing

  // Step 3 — Upload
  bool _isUploading = false;
  String? _uploadError;
  String? _createdNameId;

  @override
  void dispose() {
    _nameController.dispose();
    _recordTimer?.cancel();
    _audioPlayer.dispose();
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
      final record = await NameService.instance.createName(_nameController.text.trim());
      _createdNameId = record['id'];

      final hasMic = await AudioRecordingService.instance.ensureMicPermission();
      if (!hasMic) {
        if (mounted) _showMicPermissionDialog();
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
    if (_isRecording) return;

    try {
      // Stop any playback
      await _audioPlayer.stop();
      setState(() => _playingIndex = null);

      await AudioRecordingService.instance.startRecording(_nextIndex);
      setState(() {
        _isRecording = true;
        _recordProgress = 0;
      });

      // Auto-stop after 2 seconds
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
        _samples.add(VoiceSample(
          index: _nextIndex,
          filePath: path,
          recordedAt: DateTime.now(),
        ));
        _nextIndex++;
        _recordProgress = 0;
      });
    }
  }

  Future<void> _playSample(int listIndex) async {
    final sample = _samples[listIndex];

    if (_playingIndex == listIndex) {
      // Stop playback
      await _audioPlayer.stop();
      setState(() => _playingIndex = null);
      return;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(sample.filePath));
      setState(() => _playingIndex = listIndex);

      // Auto-reset when done
      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _playingIndex = null);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playback failed'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSample(int listIndex) async {
    if (_isRecording) return;

    // Stop playback if playing this sample
    if (_playingIndex == listIndex) {
      await _audioPlayer.stop();
      _playingIndex = null;
    }

    final sample = _samples[listIndex];
    await AudioRecordingService.instance.deleteSampleFile(sample.filePath);

    setState(() {
      _samples.removeAt(listIndex);
      // Reset playing index if needed
      if (_playingIndex != null && _playingIndex! >= _samples.length) {
        _playingIndex = null;
      }
    });
  }

  // ─────────── Step 3: Upload ───────────

  Future<void> _uploadSamples() async {
    if (_createdNameId == null || _samples.length < _minSamples) return;

    setState(() {
      _currentStep = 2;
      _isUploading = true;
      _uploadError = null;
    });

    try {
      await AudioRecordingService.instance.uploadSamples(
        nameId: _createdNameId!,
        samples: _samples,
      );

      // Initialize training status record (Redundant with DB trigger for reliability)
      await TrainingService.instance.initializeTrainingStatus(_createdNameId!);

      await AudioRecordingService.instance.cleanupTempFiles();

      if (mounted) {
        setState(() => _isUploading = false);
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

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
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
          ),

          const SizedBox(height: 24),

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
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentNavy),
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
          Text('Only letters, max 20 characters', style: AppTypography.metadata(color: AppColors.textSecondary)),

          const SizedBox(height: 32),

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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
    final hasEnough = _samples.length >= _minSamples;

    return Column(
      key: const ValueKey('step_record'),
      children: [
        // Top section — name badge + record button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: AppColors.white,
          child: Column(
            children: [
              // Name badge
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

              const SizedBox(height: 16),

              // Counter
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${_samples.length}',
                      style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 28),
                    ),
                    TextSpan(
                      text: ' / $_minSamples min',
                      style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Record button
              GestureDetector(
                onTap: _isRecording ? null : _startRecording,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _isRecording ? _recordProgress : 0,
                        strokeWidth: 3,
                        backgroundColor: AppColors.divider,
                        color: _isRecording ? AppColors.error : AppColors.primaryNavy,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _isRecording ? AppColors.error : AppColors.primaryNavy,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                          color: AppColors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _isRecording ? 'Recording...' : 'Tap to record',
                style: AppTypography.bodySmall(
                  color: _isRecording ? AppColors.error : AppColors.textSecondary,
                ).copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),

        const Divider(color: AppColors.divider, height: 1),

        // Samples list — scrollable
        Expanded(
          child: _samples.isEmpty
              ? Center(
                  child: Text(
                    'Record at least $_minSamples voice samples',
                    style: AppTypography.bodyMedium(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: _samples.length,
                  itemBuilder: (context, index) {
                    final sample = _samples[index];
                    final isPlaying = _playingIndex == index;
                    final sampleNum = index + 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          // Sample number
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '$sampleNum',
                                style: AppTypography.bodySmall(color: AppColors.success).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sample $sampleNum',
                                  style: AppTypography.bodySmall(color: AppColors.textPrimary).copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _formatTime(sample.recordedAt),
                                  style: AppTypography.metadata(color: AppColors.textSecondary).copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),

                          // Play button
                          IconButton(
                            onPressed: () => _playSample(index),
                            icon: Icon(
                              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                              color: isPlaying ? AppColors.accentNavy : AppColors.primaryNavy,
                              size: 22,
                            ),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            splashRadius: 20,
                          ),

                          // Delete button
                          IconButton(
                            onPressed: _isRecording ? null : () => _deleteSample(index),
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: _isRecording ? AppColors.divider : AppColors.textSecondary,
                              size: 20,
                            ),
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Bottom action bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: hasEnough ? _uploadSamples : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.divider,
                  disabledForegroundColor: AppColors.textSecondary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  hasEnough
                      ? 'Save & Upload (${_samples.length} samples)'
                      : '${_minSamples - _samples.length} more samples needed',
                  style: AppTypography.bodyMedium(
                    color: hasEnough ? AppColors.white : AppColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
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
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryNavy),
              ),
              const SizedBox(height: 24),
              Text(
                'Uploading ${_samples.length} samples...',
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
                decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
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
