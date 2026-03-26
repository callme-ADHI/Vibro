// VIBRO Main Shell — Navigation host with bottom navbar
import 'package:flutter/material.dart';
import '../widgets/vibro_bottom_nav.dart';
import 'home_page.dart';
import 'names_page.dart';
import 'listening_page.dart';
import 'live_captions_page.dart';
import 'settings_page.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    NamesPage(),
    ListeningPage(),
    LiveCaptionsPage(),
    SettingsPage(),
  ];

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
