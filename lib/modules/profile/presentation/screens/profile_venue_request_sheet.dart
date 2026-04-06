import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/profile_venue_models.dart';
import 'profile_venue_support.dart';

part 'profile_venue_request_sheet_actions.dart';
part 'profile_venue_request_sheet_sections.dart';

Future<VenueRequestPayload?> showVenueRequestBottomSheet({
  required BuildContext context,
  required List<VenueOption> allVenues,
  required List<VenueLookupOption> cities,
  required Set<String> acceptedIds,
  required Set<String> pendingIds,
  required Future<List<VenueLookupOption>> Function(String cityId)
  fetchDistricts,
  required Future<List<VenueLookupOption>> Function(String districtId)
  fetchNeighborhoods,
  required bool Function() isMounted,
}) {
  return showModalBottomSheet<VenueRequestPayload>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navBlueDeep,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _VenueRequestSheet(
      allVenues: allVenues,
      cities: cities,
      acceptedIds: acceptedIds,
      pendingIds: pendingIds,
      fetchDistricts: fetchDistricts,
      fetchNeighborhoods: fetchNeighborhoods,
      isMounted: isMounted,
    ),
  );
}

class _VenueRequestSheet extends StatefulWidget {
  final List<VenueOption> allVenues;
  final List<VenueLookupOption> cities;
  final Set<String> acceptedIds;
  final Set<String> pendingIds;
  final Future<List<VenueLookupOption>> Function(String cityId) fetchDistricts;
  final Future<List<VenueLookupOption>> Function(String districtId)
  fetchNeighborhoods;
  final bool Function() isMounted;

  const _VenueRequestSheet({
    required this.allVenues,
    required this.cities,
    required this.acceptedIds,
    required this.pendingIds,
    required this.fetchDistricts,
    required this.fetchNeighborhoods,
    required this.isMounted,
  });

  @override
  State<_VenueRequestSheet> createState() => _VenueRequestSheetState();
}

class _VenueRequestSheetState extends State<_VenueRequestSheet> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedVenueId;
  String _searchQuery = '';
  bool _filtersExpanded = false;

  String? _selectedCityId;
  String? _selectedDistrictId;
  String? _selectedNeighborhoodId;
  List<VenueLookupOption> _districtOptions = const [];
  List<VenueLookupOption> _neighborhoodOptions = const [];
  bool _loadingDistricts = false;
  bool _loadingNeighborhoods = false;

  void _updateState(VoidCallback updater) {
    if (!mounted) return;
    setState(updater);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredVenues = _filteredVenues();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height:
              MediaQuery.of(context).size.height *
              (_filtersExpanded ? 0.93 : 0.84),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Caldigin Mekanlari Duzenle',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSearchInput(),
                const SizedBox(height: 10),
                _buildFilterToggle(),
                if (_filtersExpanded) ...[
                  const SizedBox(height: 8),
                  _buildFiltersPanel(),
                ],
                const SizedBox(height: 10),
                Expanded(child: _buildVenueList(filteredVenues)),
                _buildFooterButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
