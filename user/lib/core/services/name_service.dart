// VIBRO Name Service — CRUD for trained_names table
import 'package:supabase_flutter/supabase_flutter.dart';

class NameService {
  NameService._();
  static final NameService instance = NameService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Get current user ID
  String? get _userId => _client.auth.currentUser?.id;

  /// Fetch all trained names for the current user
  Future<List<Map<String, dynamic>>> getNames() async {
    if (_userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('trained_names')
        .select()
        .eq('user_id', _userId!)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Check if a name already exists for the current user
  Future<bool> nameExists(String nameLabel) async {
    if (_userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('trained_names')
        .select('id')
        .eq('user_id', _userId!)
        .eq('name_label', nameLabel.trim())
        .maybeSingle();

    return response != null;
  }

  /// Create a new trained name entry
  /// Returns the created record with its UUID
  Future<Map<String, dynamic>> createName(String nameLabel) async {
    if (_userId == null) throw Exception('Not authenticated');

    final trimmed = nameLabel.trim();
    if (trimmed.isEmpty) throw Exception('Name cannot be empty');

    // Check for duplicates
    final exists = await nameExists(trimmed);
    if (exists) throw Exception('Name "$trimmed" already exists');

    final response = await _client
        .from('trained_names')
        .insert({
          'user_id': _userId!,
          'name_label': trimmed,
        })
        .select()
        .single();

    return response;
  }

  /// Delete a trained name by ID
  Future<void> deleteName(String nameId) async {
    if (_userId == null) throw Exception('Not authenticated');

    await _client
        .from('trained_names')
        .delete()
        .eq('id', nameId)
        .eq('user_id', _userId!);
  }

  /// Get audio submission status for a trained name
  Future<Map<String, dynamic>?> getAudioSubmission(String nameId) async {
    if (_userId == null) throw Exception('Not authenticated');

    final response = await _client
        .from('audio_submissions')
        .select()
        .eq('trained_name_id', nameId)
        .eq('user_id', _userId!)
        .order('uploaded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }
}
