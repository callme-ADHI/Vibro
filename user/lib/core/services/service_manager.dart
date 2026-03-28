import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'background_service.dart';
import 'foreground_service.dart';

/// Manages the unified startup of background services
/// only after permissions are granted and user is authenticated.
class ServiceManager {
  static Future<void> ensureStarted({String mode = 'deaf'}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      print('DEBUG SERVICE: Skip start — No authenticated user');
      return;
    }

    // 1. Request permissions if not granted
    final micStatus = await Permission.microphone.status;
    final notificationStatus = await Permission.notification.status;

    if (micStatus.isDenied || notificationStatus.isDenied) {
       print('DEBUG SERVICE: Requesting permissions...');
       await [
         Permission.microphone,
         Permission.notification,
       ].request();
    }

    // 2. Re-check critical microphone permission for Android 14+ FGS
    if (await Permission.microphone.isGranted) {
      print('DEBUG SERVICE: Starting services (mode=$mode)...');
      
      // Initialize Background Engine
      try {
        await BackgroundService.initialize();
      } catch (e) {
        print('DEBUG SERVICE: BackgroundService error: $e');
      }

      // Start Android Foreground Keep-alive
      try {
        await VibroForegroundService.instance.start(mode: mode);
      } catch (e) {
        print('DEBUG SERVICE: ForegroundService error: $e');
      }
    } else {
      print('DEBUG SERVICE: Microphone permission DENIED. Cannot start services.');
    }
  }

  static Future<void> stopAll() async {
     await VibroForegroundService.instance.stop();
     // BackgroundService doesn't have a direct static stop yet, but we handle it via listeners
  }
}
