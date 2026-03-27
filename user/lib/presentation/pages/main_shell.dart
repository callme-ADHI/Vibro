// VIBRO Main Shell — Navigation host with bottom navbar
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../widgets/vibro_bottom_nav.dart';
import 'home_page.dart';
import 'names_page.dart';
import 'listening_page.dart';
import 'live_captions_page.dart';
import 'settings_page.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    HomePage(),
    NamesPage(),
    ListeningPage(),
    LiveCaptionsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // 1. Listen for background detection events
    FlutterBackgroundService().on('onDetection').listen((event) {
      if (mounted && _currentIndex != 3) {
        setState(() => _currentIndex = 3);
      }
    });

    // 2. Listen for native auto-open triggers (MethodChannel)
    final channel = MethodChannel('com.vibro.app/launch');
    channel.setMethodCallHandler((call) async {
       if (call.method == "onAutoOpenTriggered") {
         if (mounted && _currentIndex != 3) {
           setState(() => _currentIndex = 3);
         }
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: VibroBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
