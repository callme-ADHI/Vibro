// VIBRO — Recognition Service (speech_to_text based, from blablabala)
// Uses device native speech recognition for name detection
// https://github.com/callme-ADHI/blablabala
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../constants/app_constants.dart';
import 'kws_service.dart'; // Reuse DetectionEvent for compatibility

/// Real-time name recognition using device speech-to-text.
/// Replaces TFLite-based KWS with native speech recognition.
class RecognitionService {
  RecognitionService._();
  static final RecognitionService instance = RecognitionService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  StreamController<DetectionEvent>? _detectionController;

  Set<String> _activeNames = {};
  DateTime? _lastDetection;
  String? _lastDetectedName;
  Timer? _restartTimer;

  bool get isListening => _isListening;
  Set<String> get activeNames => Set.unmodifiable(_activeNames);

  /// Initialize for listening. Names to detect (e.g. from trained_names).
  Future<bool> initialize(Set<String> names) async {
    if (names.isEmpty) return false;

    final available = await _speech.initialize(
      onError: (error) => print('Speech error: $error'),
      onStatus: (status) {
        if (status == 'notListening' && _isListening) {
          _scheduleRestart();
        }
      },
    );

    if (!available) {
      print('Speech recognition not available on this device');
      return false;
    }

    _activeNames = names.toSet();
    return true;
  }

  /// Start continuous listening. Returns stream of detection events.
  Stream<DetectionEvent> startListening() {
    _detectionController?.close();
    _detectionController = StreamController<DetectionEvent>.broadcast();
    _isListening = true;
    _startContinuousListening();
    return _detectionController!.stream;
  }

  /// Stop listening
  void stopListening() {
    _isListening = false;
    _restartTimer?.cancel();
    _speech.stop();
    _detectionController?.close();
    _detectionController = null;
  }

  Future<void> _startContinuousListening() async {
    if (!_isListening) return;

    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          _processTranscription(result.recognizedWords, result.confidence);
        }
      },
      listenFor: const Duration(seconds: 100),
      pauseFor: const Duration(seconds: 3),
      partialResults: false,
      cancelOnError: false,
      listenMode: stt.ListenMode.confirmation,
    );

    _scheduleRestart();
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    if (!_isListening) return;

    _restartTimer = Timer(const Duration(seconds: 3), () async {
      if (_isListening) {
        await _speech.stop();
        await Future.delayed(const Duration(milliseconds: 500));
        _startContinuousListening();
      }
    });
  }

  void _processTranscription(String transcript, double confidence) {
    if (transcript.isEmpty) return;

    final transcriptLower = transcript.toLowerCase();

    for (final name in _activeNames) {
      final nameLower = name.toLowerCase();
      if (!transcriptLower.contains(nameLower)) continue;

      final meetsThreshold =
          confidence >= AppConstants.speechRecognitionConfidenceThreshold;
      if (!meetsThreshold) continue;

      _handleDetection(name, confidence);
      return; // One detection per transcript
    }
  }

  void _handleDetection(String name, double confidence) {
    if (_lastDetection != null && _lastDetectedName == name) {
      final elapsed = DateTime.now().difference(_lastDetection!);
      if (elapsed.inSeconds < AppConstants.detectionCooldownSeconds) {
        return;
      }
    }

    _lastDetection = DateTime.now();
    _lastDetectedName = name;

    final event = DetectionEvent(
      name: name,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
    _detectionController?.add(event);
  }

  void dispose() {
    _restartTimer?.cancel();
    stopListening();
  }
}
