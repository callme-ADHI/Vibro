// VIBRO Names Page — Display and manage trained voice names
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/name_service.dart';
import 'add_name_page.dart';

class NamesPage extends StatefulWidget {
  const NamesPage({super.key});

  @override
  State<NamesPage> createState() => _NamesPageState();
}

class _NamesPageState extends State<NamesPage> {
  List<Map<String, dynamic>> _names = [];
  final Map<String, Map<String, dynamic>?> _audioStatuses = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final names = await NameService.instance.getNames();

      // Fetch audio submission status for each name
      for (final name in names) {
        try {
          final status = await NameService.instance.getAudioSubmission(name['id']);
          _audioStatuses[name['id']] = status;
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _names = names;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _deleteName(String nameId, String nameLabel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Delete "$nameLabel"?',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
        ),
        content: Text(
          'This will permanently delete the name and all associated voice samples.',
          style: AppTypography.bodyMedium(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: AppTypography.bodyMedium(color: AppColors.error).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await NameService.instance.deleteName(nameId);
        _loadNames();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: ${e.toString().replaceFirst("Exception: ", "")}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToAddName() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddNamePage()),
    );

    // Refresh if a name was added
    if (result == true) {
      _loadNames();
    }
  }

  String _getStatus(String nameId) {
    final submission = _audioStatuses[nameId];
    if (submission == null) return 'No Samples';
    final status = submission['status'] as String? ?? 'uploaded';
    switch (status) {
      case 'uploaded':
        return 'Ready';
      case 'queued':
      case 'processing':
        return 'Training';
      case 'completed':
        return 'Trained';
      case 'failed':
        return 'Failed';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String nameId) {
    final submission = _audioStatuses[nameId];
    if (submission == null) return AppColors.textSecondary;
    final status = submission['status'] as String? ?? 'uploaded';
    switch (status) {
      case 'uploaded':
        return AppColors.accentNavy;
      case 'queued':
      case 'processing':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  int _getClipCount(String nameId) {
    final submission = _audioStatuses[nameId];
    return (submission?['clip_count'] as int?) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Names',
          style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22),
        ),
        actions: [
          IconButton(
            onPressed: _navigateToAddName,
            icon: const Icon(Icons.add_rounded, color: AppColors.primaryNavy, size: 26),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryNavy,
              ),
            )
          : _error != null
              ? _buildErrorState()
              : _names.isEmpty
                  ? _buildEmptyState()
                  : _buildNamesList(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.divider),
            const SizedBox(height: 16),
            Text(
              'Failed to load names',
              style: AppTypography.bodyMedium(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadNames,
              child: Text(
                'Retry',
                style: AppTypography.bodyMedium(color: AppColors.accentNavy).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.badgeBackground,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.person_add_rounded, size: 30, color: AppColors.primaryNavy),
            ),
            const SizedBox(height: 20),
            Text(
              'No voices trained yet',
              style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a name to start voice training.\nVibro will learn to recognize specific voices.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _navigateToAddName,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'Add Name',
                  style: AppTypography.bodyMedium(color: AppColors.white).copyWith(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNamesList() {
    return RefreshIndicator(
      onRefresh: _loadNames,
      color: AppColors.primaryNavy,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _names.length,
        itemBuilder: (context, index) {
          final name = _names[index];
          final nameId = name['id'] as String;
          final nameLabel = name['name_label'] as String;
          final status = _getStatus(nameId);
          final statusColor = _getStatusColor(nameId);
          final clipCount = _getClipCount(nameId);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Navy left accent border
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primaryNavy,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Name avatar
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.badgeBackground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  nameLabel[0].toUpperCase(),
                                  style: AppTypography.sectionTitle(color: AppColors.primaryNavy).copyWith(fontSize: 18),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    nameLabel,
                                    style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '$clipCount samples',
                                        style: AppTypography.metadata(color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        status,
                                        style: AppTypography.metadata(color: statusColor).copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            // Delete action
                            IconButton(
                              onPressed: () => _deleteName(nameId, nameLabel),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              splashRadius: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
