// VIBRO Audio Recording Service — Record, playback, cache, and upload voice samples
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';

/// Represents a single recorded voice sample
class VoiceSample {
  final int index;
  final String filePath;
  final DateTime recordedAt;

  VoiceSample({
    required this.index,
    required this.filePath,
    required this.recordedAt,
  });
}

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
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  /// Delete a specific sample file
  Future<void> deleteSampleFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get file size in KB
  Future<double> getFileSizeKB(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      final bytes = await file.length();
      return bytes / 1024;
    }
    return 0;
  }

  /// Upload all recorded samples to Supabase Storage
  Future<String> uploadSamples({
    required String nameId,
    required List<VoiceSample> samples,
  }) async {
    if (_userId == null) throw Exception('Not authenticated');
    if (samples.length < 10) throw Exception('Minimum 10 samples required');

    final storagePath = '$_userId/$nameId';

    // Upload each sample
    for (int i = 0; i < samples.length; i++) {
      final file = File(samples[i].filePath);

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
      'user_id': _userId!,
      'trained_name_id': nameId,
      'clip_count': samples.length,
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
