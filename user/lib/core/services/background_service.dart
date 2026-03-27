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

    // 2. Create the HIGH-priority detection channel (needed for fullScreenIntent)
    const AndroidNotificationChannel detectionChannel = AndroidNotificationChannel(
      detectionChannelId,
      'Name Detection Alerts',
      description: 'Triggers app opening when a registered name is detected',
      importance: Importance.max,
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

  final recognition = RecognitionService.instance;
  final nameService = NameService.instance;
  final locationService = LocationService.instance;

  // 2. Fetch names to monitor
  final namesData = await nameService.getNames();
  final names = namesData
      .map((n) => (n['name_label'] as String?) ?? '')
      .where((s) => s.isNotEmpty)
      .toSet();

  // Fetch location mapping
  Map<String, List<String>> nameToLocMap = await locationService.getNameToLocationMap();
  List<Map<String, dynamic>> allLocations = await locationService.getLocations();

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
    final mappedLocs = nameToLocMap[event.name];
    if (mappedLocs != null && mappedLocs.isNotEmpty) {
      print('DEBUG BG: "${event.name}" is location-restricted: $mappedLocs');
      
      // Get current location
      final Position? currentPos = await locationService.getCurrentPosition();
      if (currentPos == null) {
        print('DEBUG BG: Could not get location, suppressing restricted name');
        return; 
      }

      final activeLoc = locationService.findActiveLocation(currentPos, allLocations);
      if (activeLoc == null || !mappedLocs.contains(activeLoc['id'])) {
        print('DEBUG BG: Not in required location for "${event.name}". (Active: ${activeLoc?['location_name']})');
        return; // Suppress
      }
      print('DEBUG BG: Location MATCH for "${event.name}" at ${activeLoc['location_name']}');
    } else {
      print('DEBUG BG: "${event.name}" is set to ALWAYS trigger');
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

    // Logic to trigger App Foregrounding
    await _bringAppToForeground(event.name);
    
    // Notify the main isolate
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
      final List namesList = event['names'] as List;
      final newNames = namesList.map((e) => e.toString().toLowerCase()).toSet();
      print('DEBUG BG: Updating names to: $newNames');
      
      // Refresh location mapping cache
      nameToLocMap = await locationService.getNameToLocationMap();
      allLocations = await locationService.getLocations();
      
      await recognition.initialize(newNames);
      recognition.startListening();
    }
  });

  service.on('stopService').listen((event) {
    recognition.stopListening();
    service.stopSelf();
  });
}

Future<void> _bringAppToForeground(String name) async {
  // 0. Check preference
  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool('auto_open_enabled') ?? true;
  if (!enabled) return;

  // ★ KEY FIX: Set SharedPreferences flag so the app reads it on cold start
  await prefs.setBool('pending_auto_open', true);
  await prefs.setString('pending_auto_open_name', name);
  print('DEBUG BG: Set pending_auto_open flag for "$name"');

  // 1. Initialize notifications plugin in this isolate
  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  // Initialize the plugin (required in background isolate)
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await notifications.initialize(initSettings);

  // 2. Show high-priority notification with full-screen intent
  //    Using the channel ID that was already created in initialize()
  const androidDetails = AndroidNotificationDetails(
    'vibro_detections_high', // ★ Must match the channel created in initialize()
    'Name Detection Alerts',
    channelDescription: 'Triggers app opening when a registered name is detected',
    importance: Importance.max,
    priority: Priority.high,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
  );

  const details = NotificationDetails(android: androidDetails);

  await notifications.show(
    999,
    '$name Detected!',
    'Tap to open Live Captions',
    details,
    payload: 'navigate_to_captions',
  );

  // 3. Try to launch the activity directly
  try {
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: 'com.vibro.vibro',
      category: 'android.intent.category.LAUNCHER',
      componentName: 'com.vibro.vibro.MainActivity',
      flags: [
        0x10000000, // FLAG_ACTIVITY_NEW_TASK
        0x20000000, // FLAG_ACTIVITY_SINGLE_TOP
        0x00020000, // FLAG_ACTIVITY_REORDER_TO_FRONT
      ],
      arguments: {'auto_open': true},
    );
    await intent.launch();
    print('DEBUG BG: Intent launched successfully');
  } catch (e) {
    print('ERROR BG: Failed to launch intent: $e');
  }
}
