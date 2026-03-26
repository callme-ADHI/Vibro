// VIBRO Authentication Service - Supabase Email Auth
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Current authenticated user
  User? get currentUser => _client.auth.currentUser;

  /// Whether user is logged in
  bool get isLoggedIn => currentUser != null;

  /// Current user's email
  String? get currentEmail => currentUser?.email;

  /// Stream of auth state changes
  Stream<AuthState> get authStateStream => _client.auth.onAuthStateChange;

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Send password reset email
  Future<void> resetPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Update user profile in profiles table
  Future<void> updateUsername(String username) async {
    final user = currentUser;
    if (user == null) throw Exception('Not authenticated');

    await _client.from('profiles').update({
      'full_name': username,
    }).eq('id', user.id);
  }

  /// Get user profile from profiles table
  Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }
}
