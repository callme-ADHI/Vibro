// VIBRO Main Shell — Navigation host with bottom navbar
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../widgets/vibro_bottom_nav.dart';
import 'home_page.dart';
import 'names_page.dart';
import 'listening_page.dart';
import 'live_captions_page.dart';
import 'connectivity_page.dart';
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
    LiveCaptionsPage(),
    ListeningPage(),
    NamesPage(),
    ConnectivityPage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    // 1. Listen for background detection events (In-App Force Switch)
    FlutterBackgroundService().on('onDetection').listen((event) {
      if (mounted && _currentIndex != 1) {
        setState(() => _currentIndex = 1);
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
