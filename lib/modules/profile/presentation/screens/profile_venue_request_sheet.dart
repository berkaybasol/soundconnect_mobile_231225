import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
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
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

  _VenueRequestSheet({
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
  List<VenueLookupOption> _districtOptions = [];
  List<VenueLookupOption> _neighborhoodOptions = [];
  bool _loadingDistricts = false;
  bool _loadingNeighborhoods = false;
  int _districtGeneration = 0;
  int _neighborhoodGeneration = 0;
  bool _submitting = false;
  String? _lookupError;

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
      duration: Duration(milliseconds: 180),
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
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Mekan seç',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                _buildSearchInput(),
                SizedBox(height: 10),
                _buildFilterToggle(),
                if (_filtersExpanded) ...[
                  SizedBox(height: 8),
                  Flexible(
                    child: SingleChildScrollView(child: _buildFiltersPanel()),
                  ),
                  if (_lookupError != null)
                    Text(
                      _lookupError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
                SizedBox(height: 10),
                Expanded(child: _buildVenueList(filteredVenues)),
                SizedBox(height: 16),
                _buildFooterButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
