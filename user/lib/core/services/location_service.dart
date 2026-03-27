// VIBRO Location Service — CRUD for locations & name mapping
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
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
  Future<Map<String, dynamic>> createLocation({
    required String locationName,
    double? latitude,
    double? longitude,
    double radius = 100.0,
  }) async {
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
        .insert({
          'user_id': _userId!,
          'location_name': trimmed,
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
        })
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

  /// Get current GPS position with permission handling
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  /// Check which location geofence the user is currently in
  Map<String, dynamic>? findActiveLocation(
      Position pos, List<Map<String, dynamic>> locations) {
    for (final loc in locations) {
      final double? lat = loc['latitude'] != null ? (loc['latitude'] as num).toDouble() : null;
      final double? lon = loc['longitude'] != null ? (loc['longitude'] as num).toDouble() : null;
      final double radius = loc['radius'] != null ? (loc['radius'] as num).toDouble() : 100.0;

      if (lat != null && lon != null) {
        final distance = Geolocator.distanceBetween(pos.latitude, pos.longitude, lat, lon);
        if (distance <= radius) {
          return loc;
        }
      }
    }
    return null;
  }

  /// Get a map of NameLabel -> List of LocationIds it belongs to
  Future<Map<String, List<String>>> getNameToLocationMap() async {
    if (_userId == null) return {};

    final response = await _client
        .from('location_name_mapping')
        .select('location_id, trained_name_id');

    final mappedIds = (response as List);
    if (mappedIds.isEmpty) return {};

    final names = await _client
        .from('trained_names')
        .select('id, name_label')
        .inFilter('id', mappedIds.map((m) => m['trained_name_id']).toList());

    final Map<String, String> idToLabel = {
      for (final n in names as List) n['id'] as String: n['name_label'] as String
    };

    final Map<String, List<String>> result = {};
    for (final m in mappedIds) {
      final label = idToLabel[m['trained_name_id']];
      if (label != null) {
        result.putIfAbsent(label, () => []).add(m['location_id'] as String);
      }
    }
    return result;
  }
}
