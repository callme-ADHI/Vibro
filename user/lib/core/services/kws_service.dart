// VIBRO — Keyword Spotting Service
// Continuous mic streaming → MFCC → TFLite inference → detection events
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
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
  Interpreter? _interpreter;
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
      _interpreter = Interpreter.fromFile(File(modelPath));

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
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;
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

    _startMicStream();

    return _detectionController!.stream;
  }

  /// Stop listening and release resources.
  void stopListening() {
    _isListening = false;
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

  Future<void> _startMicStream() async {
    if (!_modelLoaded || _interpreter == null) return;

    // Check permission
    if (!await _recorder.hasPermission()) return;

    _audioBuffer.clear();
    _isListening = true;

    // Start mic stream
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AppConstants.audioSampleRate,
        numChannels: 1,
      ),
    );

    _audioSub = stream.listen((Uint8List chunk) {
      // Convert PCM bytes to doubles
      final samples = MfccExtractor.pcmBytesToDoubles(chunk);
      _audioBuffer.addAll(samples);

      // Keep only the latest _bufferSamples
      if (_audioBuffer.length > _bufferSamples * 2) {
        _audioBuffer.removeRange(0, _audioBuffer.length - _bufferSamples);
      }
    });

    // Run inference periodically
    _inferenceTimer = Timer.periodic(
      const Duration(milliseconds: _inferencePeriodMs),
      (_) => _runInference(),
    );
  }

  void _runInference() {
    if (!_isListening || _interpreter == null) return;
    if (_audioBuffer.length < _bufferSamples ~/ 2) return; // need at least 1s

    // Take the latest 2s (or whatever we have)
    final windowSize = min(_audioBuffer.length, _bufferSamples);
    final window =
        _audioBuffer.sublist(_audioBuffer.length - windowSize);
    
    // DEBUG: Only print occasionally to avoid spam, or check size
    if (_audioBuffer.length < _bufferSamples) {
       print('DEBUG: KWS - Buffering... ${_audioBuffer.length}/$_bufferSamples');
    }

    // Extract MFCC → 13 x 64 (flattened)
    final features = _mfcc.extract(window); // [13 * 64] flattened array
    
    // Compute MEAN over time (axis=1) for each coefficient
    // Input is row-major: [c0t0, c0t1... c0tN, c1t0... ]
    final inputFeatures = Float32List(13);
    final int frames = 64; // maxPadLen from extractor

    for (int c = 0; c < 13; c++) {
      double sum = 0.0;
      for (int t = 0; t < frames; t++) {
        sum += features[c * frames + t];
      }
      inputFeatures[c] = sum / frames;
    }

    // Prepare input [1, 13]
    final input = [inputFeatures]; // dimensions: [1, 13]

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
    // DEBUG: Print all detections to see what's happening
    print('DEBUG: Inference Result - Max Conf: ${maxConf.toStringAsFixed(4)} | Index: $maxIdx | Label: ${_labels[maxIdx]}');

    if (maxConf >= AppConstants.defaultConfidenceThreshold) {
      final name = _labels[maxIdx] ?? 'Unknown';
      if (name == '_background_noise_') return;

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
