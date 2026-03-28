import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Create a new account using Email & Password
  Future<AuthResponse> createAccount({
    required String email,
    required String password,
    required String fullName,
    required DateTime dob,
    required String userType,
  }) async {
    try {
      return await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'dob': dob.toIso8601String(),
          'user_type': userType, // stored in auth.users metadata
        },
      );
    } catch (e) {
      throw Exception('Failed to create account: $e');
    }
  }

  // Log in using Email & Password
  Future<AuthResponse> loginWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to log in: $e');
    }
  }

  // Save full profile to profiles table on Sign Up
  Future<void> saveProfileData({
    required String userId,
    required String uniqueUserId,
    required String email,
    required String fullName,
    required DateTime dob,
    required String role,
  }) async {
    try {
      await _supabase.from('profiles').upsert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'user_id': uniqueUserId,
        'user_type': role,     // CC = connected, UC = deaf
        'role': role,
        'dob': dob.toIso8601String().split('T').first,
      });
    } catch (e) {
      throw Exception('Failed to save profile: $e');
    }
  }

  // Fetch user_type from profiles table (used on login to route correctly)
  Future<String> fetchUserType(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('user_type, role')
          .eq('id', userId)
          .maybeSingle();
      // Check user_type first, fall back to role
      final ut = response?['user_type'] as String?;
      if (ut != null && ut.isNotEmpty) return ut;
      final role = response?['role'] as String?;
      if (role != null && role.isNotEmpty && role != 'user') return role;
      return 'deaf';
    } catch (_) {
      return 'deaf';
    }
  }

  // Get current user session
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  // Getters for status
  bool get isLoggedIn => _supabase.auth.currentUser != null;
  String? get currentEmail => _supabase.auth.currentUser?.email;
  Stream<AuthState> get authStateStream => _supabase.auth.onAuthStateChange;

  // Sign out
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Reset password
  Future<void> resetPassword({required String email}) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // Update full_name in profiles table
  Future<void> updateUsername(String fullName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _supabase.from('profiles').update({
      'full_name': fullName,
    }).eq('id', user.id);
  }

  // Get user profile (legacy support)
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
  }
}
