// VIBRO Audio Recording Service — Record, cache, and upload voice samples
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';

class AudioRecordingService {
  AudioRecordingService._();
  static final AudioRecordingService instance = AudioRecordingService._();

  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Check and request microphone permission
  Future<bool> ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  /// Check if mic permission is permanently denied
  Future<bool> isMicPermanentlyDenied() async {
    return await Permission.microphone.isPermanentlyDenied;
  }

  /// Get temp directory for storing recordings
  Future<String> _getTempDir() async {
    final dir = await getTemporaryDirectory();
    final audioDir = Directory('${dir.path}/vibro_recordings');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir.path;
  }

  /// Start recording a voice sample
  /// Returns the file path where the recording will be saved
  Future<String> startRecording(int sampleIndex) async {
    if (_isRecording) throw Exception('Already recording');

    final hasPermission = await ensureMicPermission();
    if (!hasPermission) throw Exception('Microphone permission denied');

    final tempDir = await _getTempDir();
    final filePath = '$tempDir/sample_$sampleIndex.wav';

    // Delete existing file if present
    final file = File(filePath);
    if (await file.exists()) await file.delete();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      ),
      path: filePath,
    );

    _isRecording = true;
    return filePath;
  }

  /// Stop recording
  /// Returns the file path of the recorded sample
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  /// Upload all recorded samples to Supabase Storage
  /// Returns the storage base path for the submission
  Future<String> uploadSamples({
    required String nameId,
    required int sampleCount,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');

    final tempDir = await _getTempDir();
    final storagePath = '$_userId/$nameId';
    final submissionId = _uuid.v4();

    // Upload each sample
    for (int i = 0; i < sampleCount; i++) {
      final localPath = '$tempDir/sample_$i.wav';
      final file = File(localPath);

      if (!await file.exists()) {
        throw Exception('Sample ${i + 1} not found');
      }

      // Check file size (max 500KB)
      final fileSize = await file.length();
      if (fileSize > 512000) {
        throw Exception('Sample ${i + 1} exceeds 500KB limit');
      }

      final remotePath = '$storagePath/sample_${i + 1}.wav';

      await _client.storage
          .from(AppConstants.audioSubmissionsBucket)
          .upload(
            remotePath,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );
    }

    // Create audio_submissions record
    await _client.from('audio_submissions').insert({
      'id': submissionId,
      'user_id': _userId!,
      'trained_name_id': nameId,
      'clip_count': sampleCount,
      'status': 'uploaded',
      'storage_path': storagePath,
    });

    return storagePath;
  }

  /// Clean up temp recordings
  Future<void> cleanupTempFiles() async {
    try {
      final tempDir = await _getTempDir();
      final dir = Directory(tempDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Dispose recorder
  Future<void> dispose() async {
    if (_isRecording) {
      await _recorder.stop();
      _isRecording = false;
    }
    _recorder.dispose();
  }
}
