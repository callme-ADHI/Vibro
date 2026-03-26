// Connected User Home — with listening toggle and assigned models
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/providers/connection_provider.dart';
import 'connected_user_detail_page.dart';

// Provider for assigned models for the connected user
final assignedModelsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final me = Supabase.instance.client.auth.currentUser;
  if (me == null) return [];
  // Find the relation where this connected user is the caregiver 
  final relations = await Supabase.instance.client
      .from('user_relationships')
      .select('id, relation_label, deaf_user_id')
      .eq('connected_user_id', me.id);
  
  final List<Map<String, dynamic>> result = [];
  for (final rel in relations) {
    final models = await Supabase.instance.client
        .from('relation_models')
        .select('trained_name_id, trained_names(id, name)')
        .eq('relation_id', rel['id']);
    
    // Get deaf user profile
    final deafProfile = await Supabase.instance.client
        .from('profiles')
        .select('full_name, user_id')
        .eq('id', rel['deaf_user_id'])
        .maybeSingle();

    result.add({
      'relation_id': rel['id'],
      'relation_label': rel['relation_label'] ?? 'Unknown',
      'deaf_user_id': rel['deaf_user_id'],
      'deaf_name': deafProfile?['full_name'] ?? 'Unknown',
      'models': models,
    });
  }
  return result;
});

class ConnectedHomePage extends ConsumerStatefulWidget {
  const ConnectedHomePage({super.key});

  @override
  ConsumerState<ConnectedHomePage> createState() => _ConnectedHomePageState();
}

class _ConnectedHomePageState extends ConsumerState<ConnectedHomePage> {
  bool _isListening = false;
  Timer? _pulseTimer;

  void _toggleListening() {
    setState(() => _isListening = !_isListening);
    if (_isListening) {
      _startListeningSimulation();
    } else {
      _pulseTimer?.cancel();
    }
  }

  void _startListeningSimulation() {
    // Real implementation would hook into KWS service
    // For now, listening mode is toggled with visual feedback
    _pulseTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      // In production: check KWS result, if match found → send alert
    });
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendManualAlert(String deafUserId, String label) async {
    try {
      final me = Supabase.instance.client.auth.currentUser;
      if (me == null) return;
      await Supabase.instance.client.from('relation_alerts').insert({
        'deaf_user_id': deafUserId,
        'connected_user_id': me.id,
        'relation_label': label,
        'model_name': 'manual',
        'confidence': 1.0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Alert sent!'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProvider);
    final String currentName = userProfile?['full_name'] ?? 'Caregiver';
    final connections = ref.watch(connectionProvider);
    final assignedAsync = ref.watch(assignedModelsProvider);

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.accentNavy, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.people_alt_rounded, size: 18, color: AppColors.white),
          ),
          const SizedBox(width: 10),
          Text('VIBRO CONNECT',
              style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                  .copyWith(letterSpacing: 2, fontSize: 16)),
        ]),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.divider)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider)),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(
                    currentName.isNotEmpty ? currentName[0].toUpperCase() : 'C',
                    style: AppTypography.sectionTitle(color: AppColors.white).copyWith(fontSize: 20),
                  )),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Dashboard', style: AppTypography.metadata(color: AppColors.textSecondary)),
                  Text(currentName,
                      style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18)),
                ])),
              ]),
            ),

            const SizedBox(height: 24),

            // ---- LISTENING TOGGLE ----
            Text('Listening Mode',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: _isListening ? AppColors.primaryNavy : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: _isListening ? AppColors.primaryNavy : AppColors.divider,
                        width: _isListening ? 2 : 1),
                    boxShadow: _isListening
                        ? [BoxShadow(color: AppColors.primaryNavy.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                        : []),
                child: Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                        color: _isListening ? AppColors.white.withOpacity(0.2) : AppColors.badgeBackground,
                        shape: BoxShape.circle),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                      color: _isListening ? AppColors.white : AppColors.primaryNavy,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _isListening ? 'Listening Active' : 'Tap to Start Listening',
                      style: AppTypography.bodyMedium(
                          color: _isListening ? AppColors.white : AppColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _isListening
                          ? 'Monitoring assigned models...'
                          : 'Detects calls and sends alerts to your Deaf user',
                      style: AppTypography.bodySmall(
                          color: _isListening
                              ? AppColors.white.withOpacity(0.7)
                              : AppColors.textSecondary),
                    ),
                  ])),
                  if (_isListening)
                    const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                    ),
                ]),
              ),
            ),

            const SizedBox(height: 24),

            // ---- ASSIGNED MODELS ----
            Text('My Assigned Models',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            assignedAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (_, __) => const Text('Could not load models'),
              data: (relations) {
                if (relations.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider)),
                    child: Column(children: [
                      const Icon(Icons.model_training_rounded, size: 32, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      Text('No models assigned yet.\nYour Deaf user must assign models.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall(color: AppColors.textSecondary)),
                    ]),
                  );
                }
                return Column(
                  children: relations.map((rel) {
                    final label = rel['relation_label'] ?? 'Unknown';
                    final deafName = rel['deaf_name'] ?? 'Unknown';
                    final deafId = rel['deaf_user_id'] as String;
                    final models = (rel['models'] as List<dynamic>? ?? []);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.hearing_rounded, color: AppColors.primaryNavy, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(deafName,
                                  style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                              Text('They call you: $label',
                                  style: AppTypography.metadata(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600)),
                            ])),
                            GestureDetector(
                              onTap: () => _sendManualAlert(deafId, label),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: AppColors.primaryNavy, borderRadius: BorderRadius.circular(20)),
                                child: Text('Alert', style: AppTypography.metadata(color: AppColors.white).copyWith(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ]),
                          if (models.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 10),
                            Text('Active Models:', style: AppTypography.metadata(color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 6, children: models.map((m) {
                              final name = (m['trained_names']?['name'] as String?) ?? 'Model';
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: AppColors.badgeBackground,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.primaryNavy.withOpacity(0.2))),
                                child: Text(name,
                                    style: AppTypography.metadata(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600)),
                              );
                            }).toList()),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 24),

            // ---- LINKED DEAF USERS ----
            Text('Your Deaf Users',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (connections.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider)),
                child: Column(children: [
                  const Icon(Icons.link_off_rounded, color: AppColors.textSecondary, size: 32),
                  const SizedBox(height: 12),
                  Text('No users linked yet.', style: AppTypography.bodySmall(color: AppColors.textSecondary)),
                ]),
              )
            else
              Column(
                children: connections.map((conn) {
                  final targetId = conn['connected_user_id'] ?? '';
                  final profile = conn['profiles'] as Map<String, dynamic>? ?? {};
                  final targetName = profile['full_name'] ?? 'Unknown User';
                  final targetUUID = profile['id'] as String? ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider)),
                    child: Row(children: [
                      CircleAvatar(
                        backgroundColor: AppColors.badgeBackground,
                        child: Text(targetName.isNotEmpty ? targetName[0] : 'U',
                            style: const TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(targetName,
                            style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                        Text('ID: $targetId', style: AppTypography.metadata(color: AppColors.textSecondary)),
                      ])),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ConnectedUserDetailPage(targetId: targetId, targetName: targetName))),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryNavy,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0),
                        child: const Text('Manage', style: TextStyle(fontSize: 13)),
                      ),
                    ]),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
