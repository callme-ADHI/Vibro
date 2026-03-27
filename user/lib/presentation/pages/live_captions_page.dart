import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class LiveCaptionsPage extends StatefulWidget {
  const LiveCaptionsPage({super.key});

  @override
  State<LiveCaptionsPage> createState() => _LiveCaptionsPageState();
}

class _LiveCaptionsPageState extends State<LiveCaptionsPage> {
  bool _isListening = false;
  bool _speechEnabled = true;
  
  String _currentWords = '';
  final List<String> _completedSentences = [];
  
  // Accessibility state
  bool _isHighContrast = false;
  double _textSize = 28.0;
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    final service = FlutterBackgroundService();
    
    // Check if running
    _isListening = await service.isRunning();
    
    // Listen for transcription
    service.on('onTranscription').listen((event) {
      if (!mounted) return;
      
      final String text = event?['text'] as String? ?? '';
      final bool isFinal = event?['isFinal'] as bool? ?? false;

      setState(() {
        if (isFinal) {
           if (text.isNotEmpty) _completedSentences.add(text);
           _currentWords = '';
        } else {
           _currentWords = text;
        }
      });
      _scrollToBottom();
    });

    // Periodically check status
    Timer.periodic(const Duration(seconds: 1), (timer) async {
       if (!mounted) {
         timer.cancel();
         return;
       }
       final isRunning = await service.isRunning();
       if (isRunning != _isListening) {
         setState(() => _isListening = isRunning);
       }
    });

    if (mounted) setState(() {});
  }

  void _startListening() async {
    await FlutterBackgroundService().startService();
  }

  void _stopListening() async {
    FlutterBackgroundService().invoke('stopService');
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() {
      if (result.finalResult) {
         _completedSentences.add(result.recognizedWords);
         _currentWords = '';
      } else {
         _currentWords = result.recognizedWords;
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100, // overshoot a bit to ensure it shows
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme logic based on High Contrast toggle
    final bgColor = _isHighContrast ? Colors.black : AppColors.lightSurface;
    final appBarColor = _isHighContrast ? Colors.black : AppColors.white;
    final textColor = _isHighContrast ? const Color(0xFFFFFF00) : AppColors.textPrimary; // Bright yellow for high contrast
    final secondaryTextColor = _isHighContrast ? Colors.white70 : AppColors.textSecondary;
    final dividerColor = _isHighContrast ? Colors.white24 : AppColors.divider;
    final cardColor = _isHighContrast ? const Color(0xFF111111) : AppColors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Live Captions',
          style: AppTypography.pageTitle(color: _isHighContrast ? Colors.white : AppColors.textPrimary)
              .copyWith(fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isHighContrast ? Icons.contrast_rounded : Icons.contrast_outlined,
              color: _isHighContrast ? Colors.white : AppColors.primaryNavy,
            ),
            tooltip: 'Toggle High Contrast',
            onPressed: () {
              setState(() {
                _isHighContrast = !_isHighContrast;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: _isHighContrast ? Colors.white : AppColors.textSecondary),
            tooltip: 'Clear Captions',
            onPressed: () {
              setState(() {
                _completedSentences.clear();
                _currentWords = '';
              });
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: dividerColor),
        ),
      ),
      body: Column(
        children: [
          // Accessibility Bar (Text Size)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: cardColor,
            child: Row(
              children: [
                Icon(Icons.format_size, size: 16, color: secondaryTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _textSize,
                    min: 16.0,
                    max: 48.0,
                    activeColor: _isHighContrast ? Colors.yellow : AppColors.primaryNavy,
                    inactiveColor: dividerColor,
                    onChanged: (val) {
                      setState(() {
                        _textSize = val;
                      });
                      _scrollToBottom();
                    },
                  ),
                ),
                Text(
                  '${_textSize.toInt()}pt',
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          // Caption Area
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: _completedSentences.isEmpty && _currentWords.isEmpty && !_isListening
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.closed_caption_outlined,
                            size: 64,
                            color: secondaryTextColor.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap the microphone to start listening.',
                            style: TextStyle(
                              fontSize: 16,
                              color: secondaryTextColor,
                            ),
                          ),
                          if (!_speechEnabled)
                             Padding(
                               padding: const EdgeInsets.only(top: 8.0),
                               child: Text(
                                 'Speech recognition not authorized or not available.',
                                 style: TextStyle(color: _isHighContrast ? Colors.redAccent : AppColors.error, fontSize: 14),
                                 textAlign: TextAlign.center,
                               ),
                             )
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _completedSentences.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _completedSentences.length) {
                          // Current partial sentence
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _currentWords,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: _textSize,
                                color: textColor.withOpacity(0.7), // Slightly faded for actively recognizing words
                                height: 1.4,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          );
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            _completedSentences[index],
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: _textSize,
                              color: textColor,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          
          // Control Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(
                top: BorderSide(color: dividerColor),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isListening ? 'Listening...' : 'Not Listening',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _isHighContrast ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _isListening ? 'Capturing audio in real time' : 'Paused',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _toggleListening,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? (_isHighContrast ? Colors.red : AppColors.error)
                          : (_isHighContrast ? Colors.yellow : AppColors.primaryNavy),
                      shape: BoxShape.circle,
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: (_isHighContrast ? Colors.red : AppColors.error).withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 4,
                              )
                            ]
                          : [],
                    ),
                    child: Icon(
                      _isListening ? Icons.square_rounded : Icons.mic_rounded,
                      color: _isHighContrast 
                          ? (_isListening ? Colors.white : Colors.black)
                          : AppColors.white,
                      size: _isListening ? 24 : 32,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
