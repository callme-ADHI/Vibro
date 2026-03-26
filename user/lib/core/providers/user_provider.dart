import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final userProvider = StateNotifierProvider<UserNotifier, Map<String, dynamic>?>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<Map<String, dynamic>?> {
  UserNotifier() : super(null) {
    // Auto-load if there's already a live session (e.g. app restart)
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) { state = null; return; }

      var response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // --- Resolve user_type from ALL available sources ---
      // 1. DB user_type column (most authoritative once written)
      // 2. DB role column (fallback - exists in base schema)
      // 3. Supabase auth metadata (set during signUp)
      // Never default to 'deaf' if metadata says otherwise
      String resolvedUserType = 'deaf';
      if (response != null) {
        final dbType = response['user_type'] as String?;
        final dbRole = response['role'] as String?;
        if (dbType != null && dbType.isNotEmpty) {
          resolvedUserType = dbType;
        } else if (dbRole != null && dbRole.isNotEmpty && dbRole != 'user') {
          resolvedUserType = dbRole;
        } else {
          resolvedUserType = (user.userMetadata?['user_type'] as String?) ?? 'deaf';
        }
      } else {
        resolvedUserType = (user.userMetadata?['user_type'] as String?) ?? 'deaf';
      }

      // If profile row is missing or fields are null, patch it
      final bool needsPatch = response == null ||
          response['user_id'] == null ||
          (response['full_name'] as String?)?.isEmpty != false;

      if (needsPatch) {
        final String prefix = resolvedUserType == 'connected' ? 'CC' : 'UC';
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        final rand = Random();
        final newUid = (response?['user_id'] as String?) ??
            '$prefix${String.fromCharCodes(Iterable.generate(4, (_) => chars.codeUnitAt(rand.nextInt(chars.length))))}';

        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          'full_name': (response?['full_name'] as String?)?.isNotEmpty == true
              ? response!['full_name']
              : (user.userMetadata?['full_name'] as String?) ?? 'User',
          'user_id': newUid,
          'user_type': resolvedUserType,
          'role': resolvedUserType,
        });

        // Re-fetch after patch
        response = await Supabase.instance.client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
      }

      state = response ?? {
        'id': user.id,
        'email': user.email,
        'full_name': (user.userMetadata?['full_name'] as String?) ?? 'User',
        'user_id': 'N/A',
        'user_type': resolvedUserType,
      };

    } catch (e) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        state = {
          'id': user.id,
          'email': user.email,
          'full_name': (user.userMetadata?['full_name'] as String?) ?? 'User',
          'user_id': '...',
          'user_type': (user.userMetadata?['user_type'] as String?) ?? 'deaf',
        };
      }
    }
  }

  void updateNameLocally(String newName) {
    if (state != null) state = {...state!, 'full_name': newName};
  }

  void clearProfile() {
    state = null;
  }
}
