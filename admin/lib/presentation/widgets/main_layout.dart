import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/users_screen.dart';
// import '../screens/training_screen.dart'; // TODO
// import '../screens/models_screen.dart'; // TODO
// import '../screens/settings_screen.dart'; // TODO

class MainLayout extends StatelessWidget {
  final Widget child;
  final String title;
  final int selectedIndex;

  const MainLayout({
    required this.child,
    required this.title,
    this.selectedIndex = 0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Sidebar(selectedIndex: selectedIndex),
          Expanded(
            child: Column(
              children: [
                _Header(title: title),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          const SizedBox(width: 16),
          const CircleAvatar(
            backgroundColor: Color(0xFF003366),
            child: Text("A", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class Sidebar extends StatelessWidget {
  final int selectedIndex;
  const Sidebar({required this.selectedIndex, super.key});

  void _navigate(BuildContext context, int index, Widget page) {
    if (selectedIndex == index) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.graphic_eq, color: Theme.of(context).primaryColor, size: 32),
              const SizedBox(width: 12),
              Text(
                "VIBRO ADMIN",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 48),

          _MenuItem(
            icon: Icons.dashboard_outlined,
            title: "Dashboard",
            isActive: selectedIndex == 0,
            onTap: () => _navigate(context, 0, const DashboardScreen()),
          ),
          _MenuItem(
            icon: Icons.people_outline,
            title: "Users",
            isActive: selectedIndex == 1,
            onTap: () => _navigate(context, 1, const UsersScreen()),
          ),
          _MenuItem(
            icon: Icons.mic_none,
            title: "Names & Training",
            isActive: selectedIndex == 2,
            onTap: () {}, // TODO
          ),
          _MenuItem(
            icon: Icons.model_training,
            title: "Models",
            isActive: selectedIndex == 3,
            onTap: () {}, // TODO
          ),
          const Spacer(),
          _MenuItem(
            icon: Icons.settings_outlined,
            title: "Settings",
            isActive: selectedIndex == 4,
            onTap: () {}, // TODO
          ),
          _MenuItem(
            icon: Icons.logout,
            title: "Logout",
            color: Colors.red,
            onTap: () {}, // TODO: Sign out
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isActive = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.primaryColor;
    final inactiveColor = Colors.grey[600];

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: color ?? (isActive ? activeColor : inactiveColor),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: color ?? (isActive ? activeColor : inactiveColor),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
