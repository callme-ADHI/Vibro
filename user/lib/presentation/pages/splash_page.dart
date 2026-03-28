// VIBRO Splash Page — White & Navy Enterprise
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/constants/app_constants.dart';
import '../../features/auth/screens/login_screen.dart';
import 'main_shell.dart';
import 'connected/connected_main_shell.dart';
import '../../core/services/service_manager.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryNavy,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    // Standard startup duration
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    // Reset to light status bar for rest of app
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      String userType = 'deaf';
      try {
        final profile = await Supabase.instance.client.from('profiles').select('user_type').eq('id', user.id).maybeSingle();
        if (profile != null) {
          userType = profile['user_type'] ?? 'deaf';
        }
      } catch (_) {}

      if (mounted) {
         // Safely start services for returning user
         await ServiceManager.ensureStarted(mode: userType);

         if (userType == 'connected') {
           Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ConnectedMainShell()));
         } else {
           Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 0)));
         }
      }
    } else {
      if (mounted) {
         Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo — clean, structured
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    size: 40,
                    color: AppColors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName.toUpperCase(),
                style: AppTypography.pageTitle(color: AppColors.white).copyWith(
                  fontSize: 26,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Voice Intelligence',
                style: AppTypography.bodySmall(color: Colors.white.withOpacity(0.6)).copyWith(
                  letterSpacing: 2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
