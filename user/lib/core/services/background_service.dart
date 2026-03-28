import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/app_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'recognition_service.dart';
import 'name_service.dart';
import 'location_service.dart';
import 'package:vibration/vibration.dart';

class BackgroundService {
  static const String channelId = 'vibro_background';
  static const String detectionChannelId = 'vibro_detections_high';
  static const String notificationTitle = 'Vibro Background Engine';
  static const String notificationContent = 'Monitoring for registered names...';
  static const int notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // 1. Create the low-priority persistent channel
    const AndroidNotificationChannel bgChannel = AndroidNotificationChannel(
      channelId,
      'Vibro Detection Service',
      description: 'Maintains name detection in the background',
      importance: Importance.low,
    );

    // 2. Create the standard detection channel
    const AndroidNotificationChannel detectionChannel = AndroidNotificationChannel(
      detectionChannelId,
      'Name Detection Alerts',
      description: 'Notifies when a registered name is detected',
      importance: Importance.defaultImportance, // Standard priority
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(bgChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(detectionChannel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: channelId,
        initialNotificationTitle: notificationTitle,
        initialNotificationContent: notificationContent,
        foregroundServiceTypes: [AndroidForegroundType.microphone, AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (_) => false,
      ),
    );
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  print('DEBUG BG: Service onStart called');
  DartPluginRegistrant.ensureInitialized();

  // 1. Initialize Supabase in background isolate
  print('DEBUG BG: Initializing Supabase...');
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  print('DEBUG BG: Supabase initialized');

  if (Supabase.instance.client.auth.currentUser == null) {
     print('DEBUG BG: No authenticated user found. Stopping service until login.');
     service.stopSelf();
     return;
  }

  final recognition = RecognitionService.instance;
  final nameService = NameService.instance;
  final locationService = LocationService.instance;

  // 2. Fetch data safely
  Set<String> names = {};
  Map<String, List<String>> nameToLocMap = {};
  List<Map<String, dynamic>> allLocations = [];
  bool isAutoLocation = true;
  String? selectedLocationId;

  try {
    names = await nameService.getTrainedNameLabels();
    print('DEBUG BG: Active names (trained only): $names');

    // Fetch location mapping
    nameToLocMap = await locationService.getNameToLocationMap();
    allLocations = await locationService.getLocations();
  } catch (e) {
    print('DEBUG BG: Error fetching initial data: $e');
    service.stopSelf();
    return;
  }

  if (names.isEmpty) {
    service.stopSelf();
    return;
  }

  // 3. Initialize & Start ASR
  final initSuccess = await recognition.initialize(names);
  if (initSuccess) {
    recognition.startListening();
  }

  bool isCapturingNotification = false;
  Timer? capturingTimer;

  // 4. Listen for detection events
  recognition.detectionStream.listen((event) async {
    // LOCATION FILTERING LOGIC
    final detectedName = event.name;
    bool shouldNotify = false;

    // 1. Check if the name has any location restrictions
    final allowedLocations = nameToLocMap[detectedName];

    if (allowedLocations == null || allowedLocations.isEmpty) {
      // This name is set to "Always" (no location restrictions)
      print('DEBUG BG: "$detectedName" is set to ALWAYS trigger');
      shouldNotify = true;
    } else {
      print('DEBUG BG: "$detectedName" is location-restricted: $allowedLocations');

      // 2. Determine active location for filtering
      String? activeLocId;
      if (isAutoLocation) {
        final pos = await locationService.getCurrentPosition();
        if (pos != null) {
          final activeLoc = await locationService.findActiveLocation(pos, allLocations);
          final generalLoc = allLocations.firstWhere((l) => l['location_name'] == LocationService.generalName, orElse: () => {});
          final generalId = generalLoc['id'] as String?;
          
          activeLocId = activeLoc?['id'] as String? ?? generalId;
          
          if (activeLocId != null && activeLocId == generalId) {
            print('DEBUG BG: Auto-sensing matched NO location. Using General Mode.');
          } else if (activeLocId != null) {
            print('DEBUG BG: Auto-location detected: ${activeLoc?['location_name']} (ID: $activeLocId)');
          }
        }
 else {
          print('DEBUG BG: Could not get current position for auto-location.');
        }
      } else {
        // Manual Mode
        if (selectedLocationId == '__all__' || selectedLocationId == null) {
          // If "All names" is manually selected, we don't filter by location
          print('DEBUG BG: Manual "All Names" selected. Bypassing location filter.');
          shouldNotify = true; 
        } else {
          activeLocId = selectedLocationId;
          print('DEBUG BG: Manual location selected: $activeLocId');
        }
      }

      if (!shouldNotify && activeLocId != null && allowedLocations.contains(activeLocId)) {
        // User is currently in one of the allowed locations for this name
        print('DEBUG BG: Location MATCH for "$detectedName" at $activeLocId');
        shouldNotify = true;
      }
    }

    if (!shouldNotify) {
      print('DEBUG BG: Suppressing "$detectedName" due to location restrictions.');
      return; // Suppress the detection
    }

    // Start/Reset notification captioning window
    isCapturingNotification = true;
    capturingTimer?.cancel();
    capturingTimer = Timer(const Duration(seconds: 45), () {
      isCapturingNotification = false;
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: BackgroundService.notificationTitle,
          content: BackgroundService.notificationContent,
        );
      }
    });

    // 1. Vibrate device (awarenes even if screen off)
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [0, 500, 200, 500]); // Noticeable pattern
    }

    // 2. Trigger Notification
    await _showDetectionNotification(event.name);
    
    // 3. Notify the main isolate (for in-app tab switching)
    service.invoke('onDetection', {
      'name': event.name,
      'confidence': event.confidence,
    });
  });

  recognition.transcriptionStream.listen((event) {
    if (isCapturingNotification) {
      final String text = event['text'] ?? '';
      if (text.isNotEmpty && service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Vibro: Live Captioning...',
          content: text.length > 50 ? '...' + text.substring(text.length - 47) : text,
        );
      }
    }
    service.invoke('onTranscription', event);
  });

  // 5. Remote control listeners
  service.on('updateNames').listen((event) async {
    if (event != null && event['names'] is List) {
      final names = List<String>.from(event['names']);
      isAutoLocation = event['isAutoLocation'] as bool? ?? true;
      selectedLocationId = event['selectedLocationId'] as String?;
      print('DEBUG BG: Updating names to: $names');
      print('DEBUG BG: isAutoLocation: $isAutoLocation, selectedLocationId: $selectedLocationId');
      
      await recognition.updateLabels(names);
      
      // Refresh location mapping cache
      nameToLocMap = await locationService.getNameToLocationMap();
      allLocations = await locationService.getLocations();
    }
  });

  service.on('stopService').listen((event) {
    recognition.stopListening();
    service.stopSelf();
  });
}

Future<void> _showDetectionNotification(String name) async {
  // 1. Initialize notifications plugin in this isolate
  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await notifications.initialize(initSettings);

  // 2. Show standard notification (Noticeable but NOT full-screen)
  const androidDetails = AndroidNotificationDetails(
    'vibro_detections_high', // Reusing channel ID
    'Name Detection Alerts',
    channelDescription: 'Notifies when a registered name is detected',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    fullScreenIntent: false, // NO auto-open
  );

  const details = NotificationDetails(android: androidDetails);

  await notifications.show(
    999,
    '$name Detected!',
    'Tap to view Live Captions',
    details,
    payload: 'navigate_to_captions',
  );
}
