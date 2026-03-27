import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


final logsProvider = StateNotifierProvider<LogsNotifier, List<Map<String, dynamic>>>((ref) {
  return LogsNotifier();
});

class LogsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  LogsNotifier() : super([]) {
    loadLogs();
  }

  Future<void> loadLogs() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      
      // Ideally we fetch alerts targeting the deaf users we are connected to.
      // But we must fetch connections first
      final connections = await Supabase.instance.client
          .from('user_connections')
          .select('connected_user_id')
          .eq('user_id', user.id);
          
      if (connections.isEmpty) {
        state = [];
        return;
      }
      
      final cIds = connections.map((c) => c['connected_user_id']).toList();
      
      // Get the actual UUIDs of the deaf users
      final profiles = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, user_id')
          .inFilter('user_id', cIds);
      
      final deafUUIDs = profiles.map((p) => p['id']).toList();
      
      if (deafUUIDs.isEmpty) {
        state = [];
        return;
      }

      final response = await Supabase.instance.client
          .from('alerts')
          .select()
          .inFilter('user_id', deafUUIDs)
          .order('created_at', ascending: false)
          .limit(50);
          
      // Map the full name into the alert
      final List<Map<String, dynamic>> enriched = [];
      for (var alert in response) {
        final trgUser = profiles.firstWhere((p) => p['id'] == alert['user_id'], orElse: () => {});
        enriched.add({
          ...alert,
          'target_name': trgUser['full_name'] ?? 'Unknown User',
        });
      }

      if (mounted) state = enriched;
    } catch (_) {}
  }

  Future<bool> triggerRemoteAlert(String targetUUID, String alertType) async {
     try {
       await Supabase.instance.client.from('alerts').insert({
         'user_id': targetUUID,
         'alert_type': alertType,
         'delivered': false,
       });
       await loadLogs();
       return true;
     } catch (_) {
       return false;
     }
  }
}
