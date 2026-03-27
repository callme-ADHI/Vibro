import 'package:flutter/services.dart';

/// Controls the Android Foreground Service that keeps
/// WiFi connections and speech recognition alive in background.
class VibroForegroundService {
  VibroForegroundService._();
  static final instance = VibroForegroundService._();

  static const _channel = MethodChannel('com.vibro.vibro/foreground_service');

  /// Start foreground service.
  /// [mode] = 'deaf' | 'connected'
  Future<void> start({String mode = 'deaf'}) async {
    try {
      await _channel.invokeMethod('start', {'mode': mode});
      print('VIBRO-FGS: Started (mode=$mode)');
    } catch (e) {
      print('VIBRO-FGS: Start error: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
      print('VIBRO-FGS: Stopped');
    } catch (e) {
      print('VIBRO-FGS: Stop error: $e');
    }
  }
}
