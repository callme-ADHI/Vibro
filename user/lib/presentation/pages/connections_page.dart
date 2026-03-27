// VIBRO Connections Page (Deaf User) — with relation management
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/providers/connection_provider.dart';
import '../../core/providers/user_provider.dart';
import 'deaf_relation_page.dart';

class ConnectionsPage extends ConsumerStatefulWidget {
  const ConnectionsPage({super.key});

  @override
  ConsumerState<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends ConsumerState<ConnectionsPage> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _foundUser; // preview before confirming

  Future<void> _lookupUser() async {
    final id = _controller.text.trim().toUpperCase();
    if (id.length != 6) {
      _showSnack('ID must be 6 characters (e.g. CC4A9X)', error: true);
      return;
    }
    setState(() { _isLoading = true; _foundUser = null; });
    final found = await ref.read(connectionProvider.notifier).findUserByTextId(id);
    setState(() {
      _isLoading = false;
      _foundUser = found;
    });
    if (found == null) _showSnack('User not found. Check the ID.', error: true);
  }

  Future<void> _confirmConnect() async {
    if (_foundUser == null) return;
    setState(() => _isLoading = true);
    final myType = ref.read(userProvider)?['user_type'] ?? 'deaf';
    final error = await ref.read(connectionProvider.notifier)
        .addConnection(_foundUser!['user_id'], myUserType: myType);
    setState(() { _isLoading = false; _foundUser = null; });
    _controller.clear();
    if (error == null) {
      _showSnack('Connected successfully!');
    } else {
      _showSnack(error, error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(connectionProvider);

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text('Connections',
            style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.divider)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search & Link User',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Enter a 6-character User ID to find and link a Caregiver (CCxxxx).',
                      style: AppTypography.bodySmall(color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.characters,
                        maxLength: 6,
                        decoration: InputDecoration(
                          hintText: 'Enter User ID',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _lookupUser,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentNavy,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                            : const Icon(Icons.search_rounded),
                      ),
                    ),
                  ]),
                  // Preview card
                  if (_foundUser != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppColors.badgeBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryNavy.withOpacity(0.2))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.person_search_rounded, color: AppColors.primaryNavy, size: 20),
                            const SizedBox(width: 8),
                            Text('User Found', style: AppTypography.bodySmall(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 8),
                          Text(_foundUser!['full_name'] ?? 'Unknown',
                              style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                          Text('${_foundUser!['user_id']} · ${(_foundUser!['user_type'] ?? 'deaf').toString().toUpperCase()}',
                              style: AppTypography.metadata(color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _confirmConnect,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryNavy,
                                  foregroundColor: AppColors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0),
                              child: Text('Confirm Connect',
                                  style: AppTypography.bodyMedium(color: AppColors.white).copyWith(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text('Your Connections',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary)
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            if (connections.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider)),
                child: Column(children: [
                  Icon(Icons.link_off_rounded, size: 40, color: AppColors.textSecondary.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text('No connections yet', style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
                ]),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: connections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final cxn = connections[index];
                  final profile = cxn['profiles'] as Map<String, dynamic>? ?? {};
                  final targetName = profile['full_name'] ?? 'Unknown';
                  final targetTextId = cxn['connected_user_id'] ?? '';
                  final userType = profile['user_type'] ?? 'deaf';
                  final targetUUID = profile['id'] as String?;

                  return GestureDetector(
                    onTap: targetUUID == null
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => DeafRelationPage(
                                connectedUserId: targetUUID,
                                connectedName: targetName,
                                connectedTextId: targetTextId,
                              ),
                            )),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider)),
                      child: Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                              color: AppColors.badgeBackground,
                              borderRadius: BorderRadius.circular(12)),
                          child: Center(
                            child: Icon(
                              userType == 'connected' ? Icons.people_alt_rounded : Icons.hearing_rounded,
                              color: AppColors.primaryNavy, size: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(targetName, style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                          Text('ID: $targetTextId', style: AppTypography.metadata(color: AppColors.textSecondary)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primaryNavy.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                          child: Text(userType.toUpperCase(),
                              style: AppTypography.metadata(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w700, fontSize: 10)),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                      ]),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
