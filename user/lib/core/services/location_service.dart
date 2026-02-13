// VIBRO Location Service — CRUD for locations & name mapping
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _client.auth.currentUser?.id;

  /// Get all locations for the current user
  Future<List<Map<String, dynamic>>> getLocations() async {
    if (_userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('locations')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create a new location (max 3)
  Future<Map<String, dynamic>> createLocation(String locationName) async {
    if (_userId == null) throw Exception('Not authenticated');

    final trimmed = locationName.trim();
    if (trimmed.isEmpty) throw Exception('Location name cannot be empty');

    final existing = await getLocations();
    if (existing.length >= AppConstants.maxLocations) {
      throw Exception('Maximum ${AppConstants.maxLocations} locations allowed');
    }

    final exists = existing.any(
        (l) => (l['location_name'] as String?)?.toLowerCase() == trimmed.toLowerCase());
    if (exists) throw Exception('Location "$trimmed" already exists');

    final response = await _client
        .from('locations')
        .insert({'user_id': _userId!, 'location_name': trimmed})
        .select()
        .single();

    return response;
  }

  /// Delete a location
  Future<void> deleteLocation(String locationId) async {
    if (_userId == null) throw Exception('Not authenticated');

    await _client
        .from('locations')
        .delete()
        .eq('id', locationId)
        .eq('user_id', _userId!);
  }

  /// Get names mapped to a location (returns name_label from trained_names)
  Future<List<Map<String, dynamic>>> getNamesForLocation(String locationId) async {
    if (_userId == null) throw Exception('Not authenticated');

    final mapping = await _client
        .from('location_name_mapping')
        .select('trained_name_id')
        .eq('location_id', locationId);

    final ids = (mapping as List)
        .map((r) => r['trained_name_id'] as String?)
        .whereType<String>()
        .toList();
    if (ids.isEmpty) return [];

    final names = await _client
        .from('trained_names')
        .select('id, name_label')
        .inFilter('id', ids);

    return (names as List)
        .map((n) => {
              'trained_name_id': n['id'],
              'name_label': n['name_label'],
            } as Map<String, dynamic>)
        .toList();
  }

  /// Set which names are active for a location (replaces existing mapping)
  Future<void> setNamesForLocation(
    String locationId,
    List<String> trainedNameIds,
  ) async {
    if (_userId == null) throw Exception('Not authenticated');

    await _client
        .from('location_name_mapping')
        .delete()
        .eq('location_id', locationId);

    if (trainedNameIds.isEmpty) return;

    await _client.from('location_name_mapping').insert(
          trainedNameIds
              .map((id) => {'location_id': locationId, 'trained_name_id': id})
              .toList(),
        );
  }

  /// Get name labels for a location (for listening) - simple string list
  Future<List<String>> getNameLabelsForLocation(String locationId) async {
    final mapped = await getNamesForLocation(locationId);
    return mapped
        .map((m) => m['name_label'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
