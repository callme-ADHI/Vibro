import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
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

  // Map & Picking State
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  ll.LatLng _selectedPoint = const ll.LatLng(12.9716, 77.5946); // Default Bangalore
  bool _isSearching = false;
  bool _isSaving = false;
  bool _isGettingGps = false;

  // List State
  List<Map<String, dynamic>> _locations = [];
  final Map<String, List<String>> _namesPerLocation = {};
  List<Map<String, dynamic>> _allNames = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    _goToCurrentLocation(silent: true);
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final locations = await _locationService.getLocations();
      final names = await _nameService.getNames();

      final Map<String, List<String>> namesPerLoc = {};
      for (final loc in locations) {
        final locId = loc['id'] as String;
        final mapped = await _locationService.getNamesForLocation(locId);
        namesPerLoc[locId] = mapped.map((m) => m['name_label'] as String).toList();
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

  Future<void> _goToCurrentLocation({bool silent = false}) async {
    if (!silent) setState(() => _isGettingGps = true);
    try {
      final pos = await Geolocator.getCurrentPosition();
      final point = ll.LatLng(pos.latitude, pos.longitude);
      setState(() => _selectedPoint = point);
      _mapController.move(point, 15);
    } catch (_) {
      // Ignore
    } finally {
      if (mounted && !silent) setState(() => _isGettingGps = false);
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final results = await locationFromAddress(query);
      if (results.isNotEmpty) {
        final loc = results.first;
        final point = ll.LatLng(loc.latitude, loc.longitude);
        setState(() => _selectedPoint = point);
        _mapController.move(point, 15);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Not found: $query')));
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _saveLocation() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a location name')));
      return;
    }

    if (_locations.length >= AppConstants.maxLocations) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum locations reached')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _locationService.createLocation(
        locationName: name,
        latitude: _selectedPoint.latitude,
        longitude: _selectedPoint.longitude,
        radius: 100.0,
      );
      _nameController.clear();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added "$name"')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteLocation(Map<String, dynamic> location) async {
    final name = location['location_name'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('This will remove all name assignments for this location.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );

    if (confirm == true) {
      await _locationService.deleteLocation(location['id'] as String);
      _loadData();
    }
  }

  Future<void> _editNames(Map<String, dynamic> location) async {
    final locId = location['id'] as String;
    final locName = location['location_name'] as String? ?? '';
    final current = _namesPerLocation[locId] ?? [];
    final selectedIds = <String>{};
    for (final n in _allNames) {
      if (current.contains(n['name_label'])) selectedIds.add(n['id'] as String);
    }

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _EditNamesDialog(
        locationName: locName,
        allNames: _allNames,
        selectedIds: selectedIds,
      ),
    );

    if (result != null) {
      await _locationService.setNamesForLocation(locId, result.toList());
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      appBar: AppBar(
        title: const Text('Locations'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // TOP 2/3: MAP SECTION
          SizedBox(
            height: size.height * 0.55,
            child: _buildMapSection(),
          ),
          
          // BOTTOM 1/3: LIST SECTION
          Expanded(
            child: _buildListSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _selectedPoint,
            initialZoom: 15,
            onTap: (_, point) => setState(() => _selectedPoint = point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.vibro.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _selectedPoint,
                  width: 80,
                  height: 80,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
          ],
        ),

        // Search Bar Floating
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search location...',
                border: InputBorder.none,
                icon: const Icon(Icons.search),
                suffixIcon: _isSearching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              ),
              onSubmitted: (_) => _searchAddress(),
            ),
          ),
        ),

        // GPS Button
        Positioned(
          bottom: 100,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: _goToCurrentLocation,
            backgroundColor: Colors.white,
            child: _isGettingGps 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location, color: AppColors.primaryNavy),
          ),
        ),

        // Add Location Panel (Flush at bottom of map section)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Enter name (e.g. Home)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Add'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListSection() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('No locations yet', style: AppTypography.bodyMedium(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _locations.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final loc = _locations[i];
        final id = loc['id'] as String;
        final name = loc['location_name'] as String? ?? '';
        final names = _namesPerLocation[id] ?? [];
        final namesStr = names.isEmpty ? 'No names assigned' : names.join(', ');

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE8EAF6),
              child: Icon(Icons.location_on, color: AppColors.primaryNavy, size: 20),
            ),
            title: Text(name, style: AppTypography.bodyMedium(color: AppColors.textPrimary).copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(namesStr, style: AppTypography.bodySmall(color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editNames(loc)),
                IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.error), onPressed: () => _deleteLocation(loc)),
              ],
            ),
            onTap: () => _editNames(loc),
          ),
        );
      },
    );
  }
}

class _EditNamesDialog extends StatefulWidget {
  final String locationName;
  final List<Map<String, dynamic>> allNames;
  final Set<String> selectedIds;

  const _EditNamesDialog({required this.locationName, required this.allNames, required this.selectedIds});

  @override
  State<_EditNamesDialog> createState() => _EditNamesDialogState();
}

class _EditNamesDialogState extends State<_EditNamesDialog> {
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Names for ${widget.locationName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.allNames.map((n) {
              final id = n['id'] as String;
              return CheckboxListTile(
                title: Text(n['name_label']),
                value: _selectedIds.contains(id),
                onChanged: (v) => setState(() => v == true ? _selectedIds.add(id) : _selectedIds.remove(id)),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, _selectedIds), child: const Text('Save')),
      ],
    );
  }
}
