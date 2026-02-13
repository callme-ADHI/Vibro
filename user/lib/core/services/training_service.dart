// VIBRO Training Service — Status tracking + model download
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// Training status values matching DB enum
enum TrainingStatus {
  notStarted,
  downloadingAudio,
  training,
  uploadingModel,
  completed,
  failed;

  static TrainingStatus fromString(String value) {
    switch (value) {
      case 'NOT_STARTED':
        return TrainingStatus.notStarted;
      case 'DOWNLOADING_AUDIO':
        return TrainingStatus.downloadingAudio;
      case 'TRAINING':
        return TrainingStatus.training;
      case 'UPLOADING_MODEL':
        return TrainingStatus.uploadingModel;
      case 'COMPLETED':
        return TrainingStatus.completed;
      case 'FAILED':
        return TrainingStatus.failed;
      default:
        return TrainingStatus.notStarted;
    }
  }

  String get displayText {
    switch (this) {
      case TrainingStatus.notStarted:
        return 'Not Started';
      case TrainingStatus.downloadingAudio:
        return 'Preparing audio...';
      case TrainingStatus.training:
        return 'Training model...';
      case TrainingStatus.uploadingModel:
        return 'Finalizing model...';
      case TrainingStatus.completed:
        return 'Model Ready';
      case TrainingStatus.failed:
        return 'Training Failed';
    }
  }

  bool get isInProgress =>
      this == TrainingStatus.downloadingAudio ||
      this == TrainingStatus.training ||
      this == TrainingStatus.uploadingModel;
}

/// Data class for training status
class TrainingStatusData {
  final String id;
  final String userId;
  final String trainedNameId;
  final TrainingStatus status;
  final int progressPercentage;
  final int? modelVersion;
  final String? errorMessage;
  final DateTime updatedAt;

  TrainingStatusData({
    required this.id,
    required this.userId,
    required this.trainedNameId,
    required this.status,
    required this.progressPercentage,
    this.modelVersion,
    this.errorMessage,
    required this.updatedAt,
  });

  factory TrainingStatusData.fromJson(Map<String, dynamic> json) {
    return TrainingStatusData(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      trainedNameId: json['trained_name_id'] ?? '',
      status: TrainingStatus.fromString(json['status'] ?? 'NOT_STARTED'),
      progressPercentage: json['progress_percentage'] ?? 0,
      modelVersion: json['model_version'],
      errorMessage: json['error_message'],
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class TrainingService {
  TrainingService._();
  static final TrainingService instance = TrainingService._();

  SupabaseClient get _client => Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  RealtimeChannel? _statusChannel;
  StreamController<TrainingStatusData>? _statusController;

  /// Get the current training status for the user
  Future<TrainingStatusData?> getCurrentStatus() async {
    if (_userId == null) return null;

    try {
      final response = await _client
          .from('user_training_status')
          .select()
          .eq('user_id', _userId!)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return TrainingStatusData.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  /// Subscribe to real-time training status changes
  Stream<TrainingStatusData> subscribeToStatus() {
    _statusController?.close();
    _statusController = StreamController<TrainingStatusData>.broadcast();

    _statusChannel = _client
        .channel('training_status_${_userId ?? 'none'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_training_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _userId ?? '',
          ),
          callback: (payload) {
            final data = payload.newRecord;
            if (data.isNotEmpty) {
              _statusController?.add(TrainingStatusData.fromJson(data));
            }
          },
        )
        .subscribe();

    return _statusController!.stream;
  }

  /// Unsubscribe from realtime
  Future<void> unsubscribe() async {
    await _statusChannel?.unsubscribe();
    _statusChannel = null;
    _statusController?.close();
    _statusController = null;
  }

  /// Get the latest model version from DB
  Future<Map<String, dynamic>?> getLatestModel() async {
    if (_userId == null) return null;

    try {
      final response = await _client
          .from('trained_models')
          .select()
          .eq('user_id', _userId!)
          .order('model_version', ascending: false)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Get local stored model version
  Future<int> getLocalModelVersion() async {
    final dir = await getApplicationDocumentsDirectory();
    final versionFile = File('${dir.path}/vibro_model_version.txt');
    if (await versionFile.exists()) {
      final content = await versionFile.readAsString();
      return int.tryParse(content.trim()) ?? 0;
    }
    return 0;
  }

  /// Save local model version
  Future<void> _saveLocalModelVersion(int version) async {
    final dir = await getApplicationDocumentsDirectory();
    final versionFile = File('${dir.path}/vibro_model_version.txt');
    await versionFile.writeAsString(version.toString());
  }

  /// Download model if newer version available
  /// Returns true if a new model was downloaded
  Future<bool> downloadModelIfNeeded() async {
    if (_userId == null) return false;

    final latestModel = await getLatestModel();
    if (latestModel == null) return false;

    final remoteVersion = latestModel['model_version'] as int;
    final localVersion = await getLocalModelVersion();

    if (remoteVersion <= localVersion) return false;

    // Download the model
    final modelPath = latestModel['model_path'] as String;
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/vibro_models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }

    try {
      // Direct download from storage
      final Uint8List modelData = await _client.storage
          .from(AppConstants.trainedModelsBucket)
          .download(modelPath);

      final localModelPath = '${modelDir.path}/model_v$remoteVersion.tflite';
      final file = File(localModelPath);
      await file.writeAsBytes(modelData);

      // Download labels
      final labelsPath = modelPath.replaceFirst('model_v', 'labels_v').replaceFirst('.tflite', '.json');
      try {
        final labelsData = await _client.storage
            .from(AppConstants.trainedModelsBucket)
            .download(labelsPath);

        final labelsFile = File('${modelDir.path}/labels_v$remoteVersion.json');
        await labelsFile.writeAsBytes(labelsData);
      } catch (_) {
        // Labels file might not exist — non-fatal
      }

      // Save version
      await _saveLocalModelVersion(remoteVersion);

      return true;
    } catch (e) {
      throw Exception('Model download failed: $e');
    }
  }

  /// Get path to current local model
  Future<String?> getLocalModelPath() async {
    final version = await getLocalModelVersion();
    if (version == 0) return null;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/vibro_models/model_v$version.tflite';
    final file = File(path);
    if (await file.exists()) return path;
    return null;
  }

  /// Create initial training status for a user (called when user wants to start training)
  Future<void> initializeTrainingStatus(String trainedNameId) async {
    if (_userId == null) throw Exception('Not authenticated');

    await _client.from('user_training_status').upsert({
      'user_id': _userId!,
      'trained_name_id': trainedNameId,
      'status': 'NOT_STARTED',
      'progress_percentage': 0,
      'error_message': null,
    }, onConflict: 'user_id,trained_name_id');
  }
}
