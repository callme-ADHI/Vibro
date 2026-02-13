// VIBRO Locations Page — Add locations, assign names per location
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/location_service.dart';
import '../../core/services/name_service.dart';
import '../../core/constants/app_constants.dart';

class LocationsPage extends StatefulWidget {
  const LocationsPage({super.key});

  @override
  State<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends State<LocationsPage> {
  final LocationService _locationService = LocationService.instance;
  final NameService _nameService = NameService.instance;

  List<Map<String, dynamic>> _locations = [];
  final Map<String, List<String>> _namesPerLocation = {};
  List<Map<String, dynamic>> _allNames = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final locations = await _locationService.getLocations();
      final names = await _nameService.getNames();

      final Map<String, List<String>> namesPerLoc = {};
      for (final loc in locations) {
        final locId = loc['id'] as String;
        final mapped = await _locationService.getNamesForLocation(locId);
        namesPerLoc[locId] =
            mapped.map((m) => m['name_label'] as String).toList();
      }

      if (mounted) {
        setState(() {
          _locations = locations;
          _namesPerLocation.clear();
          _namesPerLocation.addAll(namesPerLoc);
          _allNames = names;
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

  Future<void> _addLocation() async {
    if (_locations.length >= AppConstants.maxLocations) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum ${AppConstants.maxLocations} locations allowed'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final name = await _showTextDialog('Add Location', 'e.g. Home, Office, Gym');
    if (name == null || name.trim().isEmpty) return;

    try {
      await _locationService.createLocation(name.trim());
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "$name"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _editNamesForLocation(Map<String, dynamic> location) async {
    final locId = location['id'] as String;
    final locName = location['location_name'] as String? ?? '';

    final current = _namesPerLocation[locId] ?? [];
    final nameIds = _allNames.map((n) => n['id'] as String).toList();
    final selectedIds = <String>{};
    for (final n in _allNames) {
      final label = n['name_label'] as String? ?? '';
      if (current.contains(label)) {
        selectedIds.add(n['id'] as String);
      }
    }

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _EditLocationNamesDialog(
        locationName: locName,
        allNames: _allNames,
        selectedIds: selectedIds,
      ),
    );

    if (result != null) {
      try {
        await _locationService.setNamesForLocation(locId, result.toList());
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Names updated'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteLocation(Map<String, dynamic> location) async {
    final name = location['location_name'] as String? ?? '';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          'Delete "$name"?',
          style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
        ),
        content: Text(
          'Name assignments for this location will be removed.',
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
        await _locationService.deleteLocation(location['id'] as String);
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "$name"'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', '')),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<String?> _showTextDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: AppTypography.sectionTitle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(controller.text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Add', style: AppTypography.bodyMedium(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Locations',
          style: AppTypography.pageTitle(color: AppColors.textPrimary).copyWith(fontSize: 22),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.divider),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                        const SizedBox(height: 16),
                        Text(_error!, textAlign: TextAlign.center, style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Add up to ${AppConstants.maxLocations} locations. Assign which names to listen for at each location.',
                        style: AppTypography.bodySmall(color: AppColors.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: _locations.isEmpty
                          ? _buildEmpty()
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                              itemCount: _locations.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final loc = _locations[i];
                                return _buildLocationCard(loc);
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _locations.length < AppConstants.maxLocations
          ? FloatingActionButton.extended(
              onPressed: _addLocation,
              backgroundColor: AppColors.primaryNavy,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Location'),
            )
          : null,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_rounded, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No locations yet',
            style: AppTypography.sectionTitle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a location (e.g. Home, Office) and assign names to listen for there.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addLocation,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Map<String, dynamic> loc) {
    final locId = loc['id'] as String;
    final locName = loc['location_name'] as String? ?? '';
    final names = _namesPerLocation[locId] ?? [];
    final namesStr = names.isEmpty ? 'No names assigned' : names.join(', ');

    return InkWell(
      onTap: () => _editNamesForLocation(loc),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.location_on_rounded, color: AppColors.primaryNavy, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locName,
                    style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    namesStr,
                    style: AppTypography.bodySmall(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
              onPressed: () => _deleteLocation(loc),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditLocationNamesDialog extends StatefulWidget {
  final String locationName;
  final List<Map<String, dynamic>> allNames;
  final Set<String> selectedIds;

  const _EditLocationNamesDialog({
    required this.locationName,
    required this.allNames,
    required this.selectedIds,
  });

  @override
  State<_EditLocationNamesDialog> createState() => _EditLocationNamesDialogState();
}

class _EditLocationNamesDialogState extends State<_EditLocationNamesDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        'Names for ${widget.locationName}',
        style: AppTypography.sectionTitle(color: AppColors.textPrimary).copyWith(fontSize: 18),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.allNames.isEmpty
            ? Text(
                'Add names first in the Names tab.',
                style: AppTypography.bodyMedium(color: AppColors.textSecondary),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.allNames.map((n) {
                    final id = n['id'] as String;
                    final label = n['name_label'] as String? ?? '';
                    return CheckboxListTile(
                      value: _selectedIds.contains(id),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedIds.add(id);
                          } else {
                            _selectedIds.remove(id);
                          }
                        });
                      },
                      title: Text(label, style: AppTypography.bodyMedium(color: AppColors.textPrimary)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selectedIds),
          child: Text('Save', style: AppTypography.bodyMedium(color: AppColors.primaryNavy).copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
