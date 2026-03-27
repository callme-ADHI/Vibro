import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Each connection includes profile info of the other user
final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, List<Map<String, dynamic>>>(
        (ref) => ConnectionNotifier());

class ConnectionNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  ConnectionNotifier() : super([]) {
    loadConnections();
  }

  Future<void> loadConnections() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final myProfile = await Supabase.instance.client
          .from('profiles')
          .select('user_id, user_type')
          .eq('id', user.id)
          .maybeSingle();
      final myTextId = myProfile?['user_id'] as String? ?? '';

      // Direction A: connections I initiated (user_id = me)
      final asInitiator = await Supabase.instance.client
          .from('user_connections')
          .select('connected_user_id, created_at')
          .eq('user_id', user.id);

      // Direction B: connections where I am the target (connected_user_id = myTextId)
      final asTarget = myTextId.isNotEmpty
          ? await Supabase.instance.client
              .from('user_connections')
              .select('user_id, created_at')
              .eq('connected_user_id', myTextId)
          : [];

      final List<Map<String, dynamic>> enriched = [];
      final Set<String> seen = {};

      // Process initiated connections — target is connected_user_id (text ID)
      for (final conn in asInitiator) {
        final targetTextId = conn['connected_user_id'] as String;
        if (seen.contains(targetTextId)) continue;
        seen.add(targetTextId);
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, user_type, user_id')
            .eq('user_id', targetTextId)
            .maybeSingle();
        enriched.add({
          'connected_user_id': targetTextId,
          'created_at': conn['created_at'],
          'profiles': profile ?? {},
        });
      }

      // Process target connections — initiator is user_id (UUID), need to look up their text ID
      for (final conn in asTarget) {
        final initiatorUUID = conn['user_id'] as String;
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('id, full_name, user_type, user_id')
            .eq('id', initiatorUUID)
            .maybeSingle();
        if (profile == null) continue;
        final textId = profile['user_id'] as String? ?? '';
        if (seen.contains(textId)) continue;
        seen.add(textId);
        enriched.add({
          'connected_user_id': textId,
          'created_at': conn['created_at'],
          'profiles': profile,
        });
      }

      if (mounted) state = enriched;
    } catch (_) {}
  }

  /// Look up a user by their 6-char text ID (UCxxxx or CCxxxx)
  Future<Map<String, dynamic>?> findUserByTextId(String textId) async {
    try {
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, user_type, user_id')
          .eq('user_id', textId.toUpperCase())
          .maybeSingle();
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Add connection with rule enforcement
  Future<String?> addConnection(String targetTextId,
      {String myUserType = 'deaf'}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return 'Not authenticated';

      final normalId = targetTextId.toUpperCase();

      // 1. Validate format
      if (normalId.length != 6) return 'User ID must be 6 characters (e.g. UC4A9X)';

      // 2. Find target profile
      final target = await findUserByTextId(normalId);
      if (target == null) return 'User not found. Check the ID and try again.';

      final targetType = target['user_type'] ?? 'deaf';

      // 3. Rule: Connected users CANNOT connect to another Connected user
      if (myUserType == 'connected' && targetType == 'connected') {
        return 'Connected Users cannot link to other Connected Users.';
      }

      // 4. Get my own text user_id
      final myProfile = await Supabase.instance.client
          .from('profiles')
          .select('user_id')
          .eq('id', user.id)
          .maybeSingle();
      if (myProfile != null && myProfile['user_id'] == normalId) {
        return 'You cannot connect to yourself.';
      }

      // 5. Prevent duplicates (check both directions)
      final existing = await Supabase.instance.client
          .from('user_connections')
          .select('id')
          .eq('user_id', user.id)
          .eq('connected_user_id', normalId)
          .maybeSingle();
      if (existing != null) return 'Already connected to this user.';

      // 6. Insert
      await Supabase.instance.client.from('user_connections').insert({
        'user_id': user.id,
        'connected_user_id': normalId,
      });

      // 7. Also create a user_relationship record (deaf-side)
      if (myUserType == 'deaf') {
        await Supabase.instance.client.from('user_relationships').insert({
          'deaf_user_id': user.id,
          'connected_user_id': target['id'],
          'relation_type': 'caregiver',
        });
      } else if (targetType == 'deaf') {
        await Supabase.instance.client.from('user_relationships').insert({
          'deaf_user_id': target['id'],
          'connected_user_id': user.id,
          'relation_type': 'caregiver',
        });
      }

      await loadConnections();
      return null; // null = success
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }
}
