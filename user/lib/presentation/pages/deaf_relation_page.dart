// Deaf User: Manage relation — set alias + assign models
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

class DeafRelationPage extends StatefulWidget {
  final String connectedUserId;   // UUID
  final String connectedName;     // Full name of caregiver
  final String connectedTextId;   // CCxxxx

  const DeafRelationPage({
    super.key,
    required this.connectedUserId,
    required this.connectedName,
    required this.connectedTextId,
  });

  @override
  State<DeafRelationPage> createState() => _DeafRelationPageState();
}

class _DeafRelationPageState extends State<DeafRelationPage> {
  final _labelController = TextEditingController();
  bool _isSaving = false;
  bool _isLoading = true;
  String? _currentLabel;
  String? _relationId;
  List<Map<String, dynamic>> _allNames = [];         // my trained names
  List<String> _assignedNameIds = [];                // IDs currently assigned

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null) return;

    try {
      // Load relation record
      final rel = await Supabase.instance.client
          .from('user_relationships')
          .select('id, relation_label')
          .eq('deaf_user_id', me.id)
          .eq('connected_user_id', widget.connectedUserId)
          .maybeSingle();

      if (rel != null) {
        _relationId = rel['id'] as String?;
        _currentLabel = rel['relation_label'] as String?;
        _labelController.text = _currentLabel ?? '';
      }

      // Load my trained names
      final names = await Supabase.instance.client
          .from('trained_names')
          .select('id, name')
          .eq('user_id', me.id);
      _allNames = List<Map<String, dynamic>>.from(names);

      // Load already assigned models for this relation
      if (_relationId != null) {
        final assigned = await Supabase.instance.client
            .from('relation_models')
            .select('trained_name_id')
            .eq('relation_id', _relationId!);
        _assignedNameIds = assigned
            .map((e) => e['trained_name_id'] as String)
            .toList();
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveLabel() async {
    final me = Supabase.instance.client.auth.currentUser;
    if (me == null || _relationId == null) return;
    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client
          .from('user_relationships')
          .update({'relation_label': _labelController.text.trim()})
          .eq('id', _relationId!);
      setState(() => _currentLabel = _labelController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Label saved!'), backgroundColor: AppColors.success));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
    setState(() => _isSaving = false);
  }

  Future<void> _toggleModel(String nameId, bool assigned) async {
    if (_relationId == null) return;
    try {
      if (assigned) {
        // Un-assign
        await Supabase.instance.client
            .from('relation_models')
            .delete()
            .eq('relation_id', _relationId!)
            .eq('trained_name_id', nameId);
        setState(() => _assignedNameIds.remove(nameId));
      } else {
        // Assign
        await Supabase.instance.client.from('relation_models').insert({
          'relation_id': _relationId!,
          'trained_name_id': nameId,
        });
        setState(() => _assignedNameIds.add(nameId));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        title: Text(widget.connectedName,
            style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 20)),
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primaryNavy),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.divider)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User info card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider)),
                    child: Row(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                            color: AppColors.badgeBackground,
                            borderRadius: BorderRadius.circular(14)),
                        child: Center(child: Text(
                          widget.connectedName.isNotEmpty ? widget.connectedName[0] : 'C',
                          style: AppTypography.sectionTitle(color: AppColors.primaryNavy).copyWith(fontSize: 22),
                        )),
                      ),
                      const SizedBox(width: 16),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.connectedName,
                            style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                        Text(widget.connectedTextId,
                            style: AppTypography.metadata(color: AppColors.textSecondary)),
                        if (_currentLabel != null && _currentLabel!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.primaryNavy.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text('You call them: $_currentLabel',
                                style: AppTypography.metadata(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600)),
                          ),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 24),

                  // Alias / Label
                  Text('Your Alias for This Person',
                      style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16)),
                  Text('This name is how they appear on alerts (e.g. "DAD", "MOM")',
                      style: AppTypography.bodySmall(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider)),
                    child: Column(
                      children: [
                        TextField(
                          controller: _labelController,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'e.g. DAD, MOM, JOHN',
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveLabel,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryNavy,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0),
                            child: _isSaving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                                : Text('Save Alias', style: AppTypography.bodyMedium(color: AppColors.white).copyWith(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Model assignment
                  Text('Assign Listening Models',
                      style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16)),
                  Text('Models you assign are automatically active when this person starts listening.',
                      style: AppTypography.bodySmall(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),

                  if (_allNames.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider)),
                      child: Column(children: [
                        const Icon(Icons.model_training_rounded, size: 32, color: AppColors.textSecondary),
                        const SizedBox(height: 8),
                        Text('No trained models found.\nTrain some models first on the Models tab.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall(color: AppColors.textSecondary)),
                      ]),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider)),
                      child: Column(
                        children: _allNames.asMap().entries.map((entry) {
                          final name = entry.value;
                          final nameId = name['id'] as String;
                          final isAssigned = _assignedNameIds.contains(nameId);
                          final isLast = entry.key == _allNames.length - 1;
                          return Column(children: [
                            ListTile(
                              leading: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                    color: isAssigned ? AppColors.primaryNavy.withOpacity(0.1) : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8)),
                                child: Icon(Icons.graphic_eq_rounded,
                                    color: isAssigned ? AppColors.primaryNavy : AppColors.textSecondary, size: 18),
                              ),
                              title: Text(name['name'] ?? 'Unknown',
                                  style: TextStyle(
                                      fontWeight: isAssigned ? FontWeight.w600 : FontWeight.w500,
                                      color: AppColors.textPrimary)),
                              trailing: Switch(
                                value: isAssigned,
                                activeColor: AppColors.primaryNavy,
                                onChanged: (_) => _toggleModel(nameId, isAssigned),
                              ),
                            ),
                            if (!isLast) const Divider(height: 1, indent: 16),
                          ]);
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
