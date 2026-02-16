// VIBRO — Keyword Spotting Service
// Continuous mic streaming → MFCC → TFLite inference → detection events
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'tflite_interpreter.dart'; // OUR WRAPPER
import '../constants/app_constants.dart';
import 'mfcc_extractor.dart';

/// A single detection event
class DetectionEvent {
  final String name;
  final double confidence;
  final DateTime timestamp;

  DetectionEvent({
    required this.name,
    required this.confidence,
    required this.timestamp,
  });
}

/// Real-time keyword spotting engine
class KwsService {
  KwsService._();
  static final instance = KwsService._();

  // ── State ──
  TfliteInterpreterWrapper? _interpreter;
  Map<int, String> _labels = {};
  bool _modelLoaded = false;
  bool _isListening = false;

  // ── Audio ──
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioSub;
  final List<double> _audioBuffer = [];
  Timer? _inferenceTimer;

  // ── MFCC ──
  final MfccExtractor _mfcc = MfccExtractor(
    sampleRate: AppConstants.audioSampleRate,
    nFft: 2048,
    hopLength: 512,
    nMels: 128,
    nMfcc: 13, // CHANGED: 13 coeffs for "Old Algorithm"
    maxPadLen: 64,
  );

  // ── Detections ──
  StreamController<DetectionEvent>? _detectionController;
  String? _lastDetectedName;
  DateTime? _lastDetectionTime;

  // ── Config ──
  // ── Config ──
  static const int _bufferDurationMs = 2000; // 2 seconds of audio
  static const int _inferencePeriodMs = 500; // run inference every 500ms
  static const int _bufferSamples =
      AppConstants.audioSampleRate * _bufferDurationMs ~/ 1000; // 32000
  static const int _cooldownMs = 1500; // min time between same-name detections

  // ═══════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════

  bool get isModelLoaded => _modelLoaded;
  bool get isListening => _isListening;
  int get labelCount => _labels.length;
  List<String> get labelNames => _labels.values.toList();

  /// Load TFLite model + labels from local storage.
  /// Returns true if model loaded successfully.
  Future<bool> loadModel() async {
    if (kIsWeb) {
      print('DEBUG: KWS - Web platform detected. Model loading skipped.');
      _modelLoaded = false;
      return false;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelDir = Directory('${dir.path}/vibro_models');

      if (!await modelDir.exists()) {
        _modelLoaded = false;
        return false;
      }

      // Find latest model version
      final files = await modelDir.list().toList();
      int latestVersion = 0;
      String? modelPath;
      String? labelsPath;

      for (final file in files) {
        final name = file.path.split('/').last;
        final versionMatch = RegExp(r'model_v(\d+)\.tflite').firstMatch(name);
        if (versionMatch != null) {
          final v = int.parse(versionMatch.group(1)!);
          if (v > latestVersion) {
            latestVersion = v;
            modelPath = file.path;
            labelsPath =
                '${modelDir.path}/labels_v$v.json';
          }
        }
      }

      if (modelPath == null || !File(modelPath).existsSync()) {
        _modelLoaded = false;
        return false;
      }

      // Load TFLite interpreter
      _interpreter?.close();
      _interpreter = getInterpreterWrapper();
      await _interpreter!.loadFromFile(modelPath);

      // Load labels
      _labels = {};
      if (File(labelsPath!).existsSync()) {
        final json = await File(labelsPath).readAsString();
        final map = jsonDecode(json) as Map<String, dynamic>;
        map.forEach((key, value) {
          _labels[int.parse(key)] = value.toString();
        });
      }

      print('DEBUG: KWS - Model loaded successfully. Path: $modelPath');
      print('DEBUG: KWS - Labels: $_labels');
      
      // Validate Input Shape
      final inputShape = _interpreter!.getInputShape(0);
      final outputShape = _interpreter!.getOutputShape(0);
      print('DEBUG: KWS - Model Input Shape: $inputShape');
      print('DEBUG: KWS - Model Output Shape: $outputShape');

      // Check if model matches current algorithm (Mean MFCC: [1, 13])
      if (inputShape.length != 2 || inputShape[1] != 13) {
        print('CRITICAL WARNING: Loaded model shape $inputShape does not match expected [1, 13].');
        print('CRITICAL WARNING: Please retrain your model with the new algorithm!');
        _modelLoaded = false; // Prevent using this model to avoid crash
        return false;
      }

      _modelLoaded = true;
      return true;
    } catch (e) {
      print('DEBUG: KWS - Model load failed: $e');
      _modelLoaded = false;
      return false;
    }
  }

  /// Start continuous listening. Returns a stream of detection events.
  Stream<DetectionEvent> startListening() {
    print('DEBUG: KWS - startListening called. Model Loaded: $_modelLoaded'); 
    
    if (!_modelLoaded) {
       print('DEBUG: KWS - Cannot start listening, model not loaded or invalid.');
       return Stream.empty();
    }

    _detectionController?.close();
    _detectionController = StreamController<DetectionEvent>.broadcast();

    _startMicCycle();

    return _detectionController!.stream;
  }

  /// Stop listening and release resources.
  void stopListening() {
    _isListening = false;
    _dutyCycleTimer?.cancel();
    _dutyCycleTimer = null;
    _inferenceTimer?.cancel();
    _inferenceTimer = null;
    _audioSub?.cancel();
    _audioSub = null;
    _audioBuffer.clear();
    _lastDetectedName = null;
    _lastDetectionTime = null;

    _recorder.stop();
  }

  /// Clean up everything.
  void dispose() {
    stopListening();
    _detectionController?.close();
    _interpreter?.close();
    _interpreter = null;
    _modelLoaded = false;
  }

  // ═══════════════════════════════════════════
  //  PRIVATE — Audio Pipeline
  // ═══════════════════════════════════════════

  // 5s listening / 1s pause timer
  Timer? _dutyCycleTimer;
  bool _isMicActive = false;

  Future<void> _startMicCycle() async {
    if (!_modelLoaded || _interpreter == null) return;
    if (!await _recorder.hasPermission()) return;
    
    _isListening = true;
    _runMicForDuration(const Duration(seconds: 5));
  }

  Future<void> _runMicForDuration(Duration duration) async {
    if (!_isListening) return;

    // Start Mic
    print('DEBUG: KWS - Mic ON (5s)');
    _isMicActive = true;
    _audioBuffer.clear();
    
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.audioSampleRate,
        numChannels: 1,
      ),
    );

    _audioSub = stream.listen((Uint8List chunk) {
      final samples = MfccExtractor.pcmBytesToDoubles(chunk);
      _audioBuffer.addAll(samples);
      // Run inference more frequently now (every 500ms while mic is on)
    });
    
    // Start Inference Timer
    _inferenceTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _runInference(),
    );

    // Schedule Pause
    _dutyCycleTimer = Timer(duration, () async {
      await _pauseMicForDuration(const Duration(seconds: 1));
    });
  }

  Future<void> _pauseMicForDuration(Duration duration) async {
    if (!_isListening) return;

    print('DEBUG: KWS - Mic PAUSE (1s)');
    _isMicActive = false;
    _inferenceTimer?.cancel();
    _audioSub?.cancel();
    await _recorder.stop();
    _audioBuffer.clear();

    // Schedule Resume
    _dutyCycleTimer = Timer(duration, () {
      _runMicForDuration(const Duration(seconds: 5));
    });
  }

  void _runInference() {
    if (!_isListening || _interpreter == null) return;
    if (_audioBuffer.length < _bufferSamples ~/ 2) return; // need at least 1s

    // Take the latest 2s (or whatever we have)
    final windowSize = min(_audioBuffer.length, _bufferSamples);
    List<double> window =
        _audioBuffer.sublist(_audioBuffer.length - windowSize);

    // CRITICAL: Trim silence to match training! Python uses librosa.effects.trim
    // on every sample. Raw mic is mostly silence → mean MFCC looks like
    // _background_noise_. Trim focuses on the speech segment.
    window = MfccExtractor.trimSilence(window, topDb: 60);

    // Extract MFCC → 13 x 64 (flattened)
    final features = _mfcc.extract(window);

    // Compute MEAN over time - use actual frame count, not 64!
    // Unfilled frames are zeros; dividing by 64 skews the mean.
    final int maxPadLen = 64;
    final actualFrames = MfccExtractor.actualFrameCount(
      window.length,
      _mfcc.nFft,
      _mfcc.hopLength,
      maxPadLen,
    );

    final inputFeatures = Float32List(13);
    for (int c = 0; c < 13; c++) {
      double sum = 0.0;
      for (int t = 0; t < actualFrames; t++) {
        sum += features[c * maxPadLen + t];
      }
      inputFeatures[c] = sum / actualFrames;
    }

    // Prepare input [1, 13]
    final input = [inputFeatures];

    // Prepare output [1, numClasses]
    final numClasses = _labels.length;
    if (numClasses == 0) return;
    
    // CHANGED: Use List<List<double>> instead of List<Float32List>
    // This prevents "type 'List<double>' is not a subtype of type 'Float32List'" error
    // if the plugin writes back a standard list.
    final output = List.generate(1, (_) => List<double>.filled(numClasses, 0.0));

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      print('DEBUG: Inference Error: $e');
      return;
    }

    // Find max confidence
    final probs = output[0];
    int maxIdx = 0;
    double maxConf = probs[0];
    for (int i = 1; i < numClasses; i++) {
      if (probs[i] > maxConf) {
        maxConf = probs[i];
        maxIdx = i;
      }
    }

    // Check threshold
    if (maxConf >= AppConstants.defaultConfidenceThreshold) {
      final name = _labels[maxIdx] ?? 'Unknown';
      if (name == '_background_noise_') return; // Must ignore background!

      final now = DateTime.now();

      // Cooldown: don't fire same name within _cooldownMs
      if (_lastDetectedName == name && _lastDetectionTime != null) {
        final elapsed = now.difference(_lastDetectionTime!).inMilliseconds;
        if (elapsed < _cooldownMs) return;
      }

      _lastDetectedName = name;
      _lastDetectionTime = now;

      print('DEBUG: VICTORY! Detected $name with confidence $maxConf');

      _detectionController?.add(DetectionEvent(
        name: name,
        confidence: maxConf,
        timestamp: now,
      ));
    }
  }

  int min(int a, int b) => a < b ? a : b;
}
