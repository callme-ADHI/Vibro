// VIBRO – CONTINUOUS SPEECH-TO-TEXT DETECTION ALGORITHM (ASR MODE)
// STRICT STATE CONTROLLER to prevent infinite restart loops
import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import '../constants/app_constants.dart';
import 'kws_service.dart'; // Import to reuse DetectionEvent

enum RecognitionState {
  IDLE,
  INITIALIZING,
  LISTENING,
  PROCESSING,
  RESTARTING,
  ERROR
}

class RecognitionService {
  RecognitionService._();
  static final RecognitionService instance = RecognitionService._();

  final SpeechToText _speech = SpeechToText();
  
  // State Management
  final StreamController<RecognitionState> _stateController = StreamController.broadcast();
  Stream<RecognitionState> get stateStream => _stateController.stream;
  
  // Detection Stream
  final StreamController<DetectionEvent> _detectionController = StreamController.broadcast();
  Stream<DetectionEvent> get detectionStream => _detectionController.stream;

  // Transcription Stream
  final StreamController<Map<String, dynamic>> _transcriptionController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get transcriptionStream => _transcriptionController.stream;

  // 🎛 STATE VARIABLES
  bool _isInitialized = false;
  bool _isListening = false;
  bool _shouldListen = false; // User intent
  bool _isRestarting = false; // Preventing overlap
  int _restartAttempts = 0;
  
  Set<String> _activeNames = {};
  DateTime? _lastTriggerTime;
  
  // CONSTANTS
  static const int _maxRestartAttempts = 5;
  static const Duration _cooldownDuration = Duration(seconds: 2); // 2s CRITICAL
  static const Duration _listenDuration = Duration(seconds: 25);
  static const Duration _pauseDuration = Duration(seconds: 3);
  static const Duration _debounceTime = Duration(seconds: 3);

  // 1️⃣ INITIALIZATION
  Future<bool> initialize(Set<String> names) async {
    _updateState(RecognitionState.INITIALIZING);
    _activeNames = names.map((e) => e.toLowerCase()).toSet();

    if (_isInitialized) {
      _updateState(RecognitionState.IDLE);
      return true;
    }

    try {
      print('DEBUG ASR: Calling _speech.initialize()...');
      _isInitialized = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
        debugLogging: true,
      );

      if (!_isInitialized) {
        print("DEBUG ASR: _speech.initialize() returned false");
        _updateState(RecognitionState.ERROR);
        return false;
      }
      
      print("DEBUG ASR: _speech.initialize() success");
      _updateState(RecognitionState.IDLE);
      return true;
    } catch (e, stack) {
      print('ERROR ASR: Speech Init Failed: $e');
      print('STACK ASR: $stack');
      _updateState(RecognitionState.ERROR);
      return false;
    }
  }

  // 2️⃣ START LISTENING (Controlled Entry)
  void startListening() {
    print('DEBUG: User requested START listening');
    
    // Validate State
    if (!_isInitialized) {
      print('DEBUG: Not initialized, aborting start');
      return;
    }
    
    // Indicate user intent
    _shouldListen = true;
    _restartAttempts = 0;
    
    // Check flags
    if (_isListening) {
      print('DEBUG: Already listening, ignoring start request');
      return;
    }
    if (_isRestarting) {
      print('DEBUG: Restart in progress, ignoring start request');
      return;
    }

    _startSession();
  }

  // 🎙 INTERNAL SESSION START
  Future<void> _startSession() async {
    // Double check user intent
    if (!_shouldListen) {
      _updateState(RecognitionState.IDLE);
      return;
    }
    
    // Check engine state
    if (_speech.isListening) {
       print('DEBUG: Engine is active, marking as listening');
       _isListening = true;
       _updateState(RecognitionState.LISTENING);
       return;
    }

    _updateState(RecognitionState.LISTENING);
    _isListening = true;

    try {
      print('DEBUG: Calling speech.listen()...');
      await _speech.listen(
        onResult: _handleResult,
        listenFor: _listenDuration,
        pauseFor: _pauseDuration,
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true, // We catch in onError
      );
    } catch (e) {
      print('ERROR: startSession exception: $e');
      _isListening = false;
      _scheduleRestart(isError: true);
    }
  }

  // 3️⃣ HANDLE RESULTS
  void _handleResult(SpeechRecognitionResult result) {
    _restartAttempts = 0; // Reset failures on success
    _updateState(RecognitionState.PROCESSING);

    final text = result.recognizedWords.toLowerCase();
    print('DEBUG ASR: HandleResult: "$text" (final: ${result.finalResult})');
    
    // Check for names
    for (final name in _activeNames) {
      if (text.contains(name)) {
        print('DEBUG ASR: MATCH FOUND for name: "$name"');
        double confidence = result.confidence;
        // Fix: Android often returns -1.0 or 0.0, use default high if matched
        if (confidence <= 0.0) confidence = 0.85; 
        
        _triggerDetection(name, confidence);
      }
    }
    
    // Emit transcription for UI
    _transcriptionController.add({
      'text': result.recognizedWords,
      'isFinal': result.finalResult,
    });
    
    // If not final, we are still listening
    if (!result.finalResult) {
       _updateState(RecognitionState.LISTENING);
    }
  }

  // 🔒 DEBOUNCE & TRIGGER
  void _triggerDetection(String name, double confidence) {
    final now = DateTime.now();
    if (_lastTriggerTime != null) {
      if (now.difference(_lastTriggerTime!) < _debounceTime) {
        return; // Debounced
      }
    }

    _lastTriggerTime = now;
    // Log clearly with sanitized confidence
    print('VICTORY: Detected "$name" ($confidence)');
    
    _detectionController.add(DetectionEvent(
      name: name,
      confidence: confidence,
      timestamp: now,
    ));
  }

  // 4️⃣ STATUS HANDLER
  void _handleStatus(String status) {
    print('DEBUG: Speech Status: $status');
    
    if (status == 'done' || status == 'notListening') {
      _isListening = false; // Mark engine as stopped
      
      // If we intended to listen, schedule a restart
      if (_shouldListen) {
        _scheduleRestart();
      } else {
        _updateState(RecognitionState.IDLE);
      }
    } else if (status == 'listening') {
      _isListening = true;
      _updateState(RecognitionState.LISTENING);
    }
  }

  // 5️⃣ ERROR HANDLER (CRITICAL FIX)
  void _handleError(SpeechRecognitionError error) {
    print('DEBUG: Speech Error: ${error.errorMsg} (permanent: ${error.permanent})');
    _isListening = false; // Error implies stopping

    if (!_shouldListen) return;

    // Handle Timeouts (Silence) as normal cycle
    if (error.errorMsg == 'error_speech_timeout' || error.errorMsg == 'error_no_match') {
       print('DEBUG ASR: Non-fatal error (${error.errorMsg}), scheduling restart...');
       _scheduleRestart();
       return;
    }
    
    // Genuine errors (busy, client, etc.)
    _updateState(RecognitionState.ERROR);
    
    // Some errors might be reported as permanent but are often transient in background
    if (error.permanent && error.errorMsg != 'error_busy') {
      _restartAttempts++;
      if (_restartAttempts > _maxRestartAttempts) {
        print('CRITICAL ASR: Max restart attempts reached for ${error.errorMsg}. Stopping.');
        stopListening();
        return;
      }
    }
    
    _scheduleRestart(isError: true);
  }

  // 🔄 SAFE RESTART LOGIC
  void _scheduleRestart({bool isError = false}) {
    if (_isRestarting) return; // Prevent double restart scheduling
    
    _isRestarting = true;
    _updateState(RecognitionState.RESTARTING);
    
    final delay = isError ? Duration(seconds: 3) : _cooldownDuration;
    
    print('DEBUG: Scheduling restart in ${delay.inMilliseconds}ms...');
    
    // Timer to release restart lock
    Timer(delay, () async {
      _isRestarting = false;
      
      // Only restart if still desired
      if (_shouldListen && !_isListening) {
        _startSession();
      } else if (!_shouldListen) {
        _updateState(RecognitionState.IDLE);
      }
    });
  }

  // ⛔ STOP LISTENING (Safe Exit)
  void stopListening() {
    print('DEBUG: Stopping ASR');
    _shouldListen = false;
    _restartAttempts = 0;
    
    if (_isListening) {
      _speech.stop();
    }
    _isListening = false;
    _updateState(RecognitionState.IDLE);
  }

  void _updateState(RecognitionState newState) {
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void dispose() {
    stopListening();
    _stateController.close();
    _detectionController.close();
    _transcriptionController.close();
  }
}
