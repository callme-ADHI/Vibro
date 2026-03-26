import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/providers/connection_provider.dart';
import '../../../core/providers/user_provider.dart';

class ConnectedConnectionsPage extends ConsumerStatefulWidget {
  const ConnectedConnectionsPage({super.key});

  @override
  ConsumerState<ConnectedConnectionsPage> createState() => _ConnectedConnectionsPageState();
}

class _ConnectedConnectionsPageState extends ConsumerState<ConnectedConnectionsPage> {
  final _controller = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _foundUser;

  Future<void> _lookupUser() async {
    final id = _controller.text.trim().toUpperCase();
    if (id.length != 6) {
      _showSnack('ID must be 6 characters (UCxxxx)', error: true);
      return;
    }
    if (!id.startsWith('UC')) {
      _showSnack('Connected Users can only link to Deaf Users (UCxxxx)', error: true);
      return;
    }
    setState(() { _isLoading = true; _foundUser = null; });
    final found = await ref.read(connectionProvider.notifier).findUserByTextId(id);
    setState(() { _isLoading = false; _foundUser = found; });
    if (found == null) _showSnack('User not found. Check the ID.', error: true);
  }

  Future<void> _confirmConnect() async {
    if (_foundUser == null) return;
    setState(() => _isLoading = true);
    final error = await ref.read(connectionProvider.notifier)
        .addConnection(_foundUser!['user_id'], myUserType: 'connected');
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
        title: Text('Connections',
            style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22)),
        backgroundColor: AppColors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.divider)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.primaryNavy.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primaryNavy.withOpacity(0.2))),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primaryNavy, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('Connected Users can only link to Deaf Users (UCxxxx).',
                    style: AppTypography.metadata(color: AppColors.primaryNavy))),
              ]),
            ),
            const SizedBox(height: 20),

            Text('Link Deaf User',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider)),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 6,
                      decoration: InputDecoration(
                        hintText: 'Enter Deaf User ID (UCxxxx)',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
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

                if (_foundUser != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: AppColors.badgeBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryNavy.withOpacity(0.2))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.person_search_rounded, color: AppColors.primaryNavy, size: 18),
                        const SizedBox(width: 8),
                        Text('Deaf User Found', style: AppTypography.bodySmall(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 8),
                      Text(_foundUser!['full_name'] ?? 'Unknown',
                          style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600)),
                      Text('${_foundUser!['user_id']} · DEAF',
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
                    ]),
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 32),
            Text('Linked Directory',
                style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            if (connections.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(24),
                  child: Text('No users linked', style: TextStyle(color: AppColors.textSecondary))))
            else
              Column(children: connections.map((conn) {
                final targetId = conn['connected_user_id'] ?? '';
                final profile = conn['profiles'] as Map<String, dynamic>? ?? {};
                final targetName = profile['full_name'] ?? 'Unknown User';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      backgroundColor: AppColors.badgeBackground,
                      child: Text(targetName.isNotEmpty ? targetName[0] : 'U',
                          style: const TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.bold))),
                  title: Text(targetName, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  subtitle: Text('ID: $targetId', style: const TextStyle(color: AppColors.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Text('DEAF', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 11)),
                  ),
                );
              }).toList()),
          ],
        ),
      ),
    );
  }
}
