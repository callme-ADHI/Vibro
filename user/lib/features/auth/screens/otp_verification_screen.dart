import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../../../../presentation/pages/home_page.dart'; // Assume this is where the main app is

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String fullName;
  final DateTime dob;
  final String userType;

  const OtpVerificationScreen({
    Key? key,
    required this.email,
    required this.fullName,
    required this.dob,
    required this.userType,
  }) : super(key: key);

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final Color _primaryNavy = const Color(0xFF0A192F);
  final Color _bgWhite = const Color(0xFFFFFFFF);
  final Color _errorRed = const Color(0xFFD32F2F);

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() {
    final token = _otpController.text.trim();
    if (token.isEmpty || token.length < 6) {
      _showErrorSnackBar('Please enter a valid OTP code.');
      return;
    }

    ref.read(authControllerProvider.notifier).verifyOtpAndSaveProfile(
      email: widget.email,
      token: token,
      fullName: widget.fullName,
      dob: widget.dob,
      userType: widget.userType,
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: _errorRed,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        _showErrorSnackBar(next.error!.replaceAll('Exception: ', ''));
      }
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        // Navigate to Main App UI
        // Example: context.go('/home') if using go_router
        // Or using standard Navigator replacement
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomePage()), // Adjust target based on routing setup
          (route) => false,
        );
      }
    });

    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: _bgWhite,
      appBar: AppBar(
        backgroundColor: _bgWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryNavy),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _primaryNavy,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a 6-digit code to:\n${widget.email}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // OTP Field
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8.0, fontWeight: FontWeight.bold),
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(color: Colors.grey.shade400, letterSpacing: 8.0),
                  counterText: "",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(vertical: 24),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade400),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _primaryNavy, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Verify Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: authState.isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryNavy,
                    foregroundColor: _bgWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'Verify & Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
