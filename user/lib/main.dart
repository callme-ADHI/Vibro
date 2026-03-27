// VIBRO Main Application Entry Point
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/services/ble_service.dart';
import 'core/services/background_service.dart';
import 'presentation/pages/splash_page.dart';

/// Global navigator key for notification tap navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global flag set when a notification is tapped with 'navigate_to_captions' payload
bool notificationAutoOpen = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  BleService.instance.initialize();

  // Initialize Background Service
  await BackgroundService.initialize();

  // Initialize Local Notifications with tap handler
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await flutterLocalNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // User tapped the "Name Detected" notification
      if (response.payload == 'navigate_to_captions') {
        notificationAutoOpen = true;
        print('DEBUG MAIN: Notification tapped — navigate_to_captions');
      }
    },
  );

  // Check if the app was launched by tapping a notification
  final launchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp == true &&
      launchDetails?.notificationResponse?.payload == 'navigate_to_captions') {
    notificationAutoOpen = true;
    print('DEBUG MAIN: App launched from notification tap');
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFFFFFFF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  print('DEBUG MAIN: Initializing Supabase...');
  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  print('DEBUG MAIN: Supabase initialized');

  runApp(
    const ProviderScope(
      child: VibroApp(),
    ),
  );
}

class VibroApp extends StatelessWidget {
  const VibroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashPage(),
    );
  }
}
