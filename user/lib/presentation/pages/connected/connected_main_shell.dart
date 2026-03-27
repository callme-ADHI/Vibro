import 'package:flutter/material.dart';
import '../../widgets/connected_bottom_nav.dart';
import 'connected_home_page.dart';
import 'connected_connections_page.dart';
import 'connected_logs_page.dart';
import 'connected_profile_page.dart';

class ConnectedMainShell extends StatefulWidget {
  const ConnectedMainShell({super.key});

  @override
  State<ConnectedMainShell> createState() => _ConnectedMainShellState();
}

class _ConnectedMainShellState extends State<ConnectedMainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ConnectedHomePage(),
    ConnectedConnectionsPage(),
    ConnectedLogsPage(),
    ConnectedProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: ConnectedBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
