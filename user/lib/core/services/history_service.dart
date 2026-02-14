// VIBRO History Service — Detection history CRUD
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class HistoryService {
  HistoryService._();
  static final HistoryService instance = HistoryService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Save a detection to history (called from ListeningPage)
  Future<void> insertDetection({
    required String nameLabel,
    required double confidence,
    String? locationId,
  }) async {
    if (_userId == null) return;

    try {
      print('DEBUG: Attempting to save detection to history for "$nameLabel"');
      
      // Attempt Case-Insensitive Lookup first
      final names = await _client
          .from('trained_names')
          .select('id')
          .eq('user_id', _userId!)
          .ilike('name_label', nameLabel) // Use ILIKE for flexibility
          .maybeSingle();

      if (names == null) {
         print('ERROR: Could not find "$nameLabel" in trained_names table.');
         return;
      }

      await _client.from('detection_history').insert({
        'user_id': _userId!,
        'trained_name_id': names['id'],
        'location_id': locationId,
        'accuracy': confidence,
        'threshold_used': AppConstants.speechRecognitionConfidenceThreshold,
        'model_version': 0, // 0 = speech-to-text
      });
      print('SUCCESS: Saved detection to history');
    } catch (e) {
      print('ERROR: Failed to save detection: $e');
    }
  }

  /// Get detection history with name and location
  Future<List<Map<String, dynamic>>> getHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('detection_history')
          .select('''
            id,
            accuracy,
            detected_at,
            trained_names(name_label),
            locations(location_name)
          ''')
          .eq('user_id', _userId!)
          .order('detected_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List).map((r) {
        final raw = Map<String, dynamic>.from(r as Map);
        final tn = raw['trained_names'];
        final loc = raw['locations'];
        return Map<String, dynamic>.from({
          ...raw,
          'name_label': tn is Map ? tn['name_label'] : null,
          'location_name': loc is Map ? loc['location_name'] : null,
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Get stats: today, this week, total
  Future<Map<String, int>> getStats() async {
    if (_userId == null) {
      return {'today': 0, 'week': 0, 'total': 0};
    }

    try {
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(Duration(days: now.weekday % 7));

      final all = await _client
          .from('detection_history')
          .select('detected_at')
          .eq('user_id', _userId!);

      int today = 0;
      int week = 0;
      for (final r in all as List) {
        final s = r['detected_at'] as String?;
        if (s == null) continue;
        final dt = DateTime.parse(s).toUtc();
        if (dt.isAfter(todayStart) || dt.isAtSameMomentAs(todayStart)) today++;
        if (dt.isAfter(weekStart) || dt.isAtSameMomentAs(weekStart)) week++;
      }

      return {
        'today': today,
        'week': week,
        'total': all.length,
      };
    } catch (_) {
      return {'today': 0, 'week': 0, 'total': 0};
    }
  }
}
