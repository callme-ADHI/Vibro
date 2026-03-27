import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../../../../core/providers/user_provider.dart';

// Provider for the AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// State for the AuthController — now carries userType so routing is reliable
class AuthState {
  final bool isLoading;
  final String? error;
  final bool isOtpSent;
  final bool isAuthenticated;
  final String userType; // 'deaf' or 'connected'

  AuthState({
    this.isLoading = false,
    this.error,
    this.isOtpSent = false,
    this.isAuthenticated = false,
    this.userType = 'deaf',
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isOtpSent,
    bool? isAuthenticated,
    String? userType,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOtpSent: isOtpSent ?? this.isOtpSent,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userType: userType ?? this.userType,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;
  final Ref _ref;

  AuthController(this._authService, this._ref) : super(AuthState());

  String _generateUniqueId(String type) {
    final prefix = type == 'connected' ? 'CC' : 'UC';
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    String rnd = String.fromCharCodes(
        Iterable.generate(4, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
    return '$prefix$rnd';
  }

  Future<void> authenticateUser({
    required String email,
    required String password,
    required String fullName,
    required DateTime dob,
    required String userType,
    required bool isLogin,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      AuthResponse response;

      if (isLogin) {
        response = await _authService.loginWithPassword(
            email: email, password: password);
      } else {
        response = await _authService.createAccount(
          email: email,
          password: password,
          fullName: fullName,
          dob: dob,
          userType: userType,
        );
      }

      if (response.user != null) {
        String resolvedUserType = userType;

        if (!isLogin) {
          // Sign Up: write full profile including user_type
          final String uniqueId = _generateUniqueId(userType);
          await _authService.saveProfileData(
            userId: response.user!.id,
            uniqueUserId: uniqueId,
            email: email,
            fullName: fullName,
            dob: dob,
            role: userType,
          );
        } else {
          // Login: read user_type from DB to know which shell to open
          resolvedUserType = await _authService.fetchUserType(response.user!.id);
        }

        // Load full profile into provider AFTER writing
        await _ref.read(userProvider.notifier).loadProfile();

        // Set isAuthenticated + userType together so the router has both
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          userType: resolvedUserType,
        );
      } else {
        state = state.copyWith(
            isLoading: false, error: 'Authentication failed. Please try again.');
      }
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Verifies OTP token (email magic link / OTP) and saves user profile.
  /// Called from OtpVerificationScreen after user enters the 6-digit code.
  Future<void> verifyOtpAndSaveProfile({
    required String email,
    required String token,
    required String fullName,
    required DateTime dob,
    required String userType,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

      if (response.user != null) {
        final String uniqueId = _generateUniqueId(userType);
        await _authService.saveProfileData(
          userId: response.user!.id,
          uniqueUserId: uniqueId,
          email: email,
          fullName: fullName,
          dob: dob,
          role: userType,
        );

        await _ref.read(userProvider.notifier).loadProfile();

        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          userType: userType,
        );
      } else {
        state = state.copyWith(
            isLoading: false, error: 'OTP verification failed. Please try again.');
      }
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          error: e.toString().replaceAll('Exception: ', ''));
    }
  }
}

// Provider for AuthController
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthController(authService, ref);
});
