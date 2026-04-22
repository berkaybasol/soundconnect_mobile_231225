part of 'profile_venue_request_sheet.dart';

extension _VenueRequestSheetStateActions on _VenueRequestSheetState {
  Future<void> _onCityChanged(String? cityId) async {
    _updateState(() {
      _selectedCityId = cityId;
      _selectedDistrictId = null;
      _selectedNeighborhoodId = null;
      _districtOptions = [];
      _neighborhoodOptions = [];
      _loadingDistricts = cityId != null;
    });
    if (cityId == null) return;
    try {
      final districts = await widget.fetchDistricts(cityId);
      if (!widget.isMounted()) return;
      _updateState(() {
        _districtOptions = districts;
        _loadingDistricts = false;
      });
    } catch (_) {
      if (!widget.isMounted()) return;
      _updateState(() => _loadingDistricts = false);
    }
  }

  Future<void> _onDistrictChanged(String? districtId) async {
    _updateState(() {
      _selectedDistrictId = districtId;
      _selectedNeighborhoodId = null;
      _neighborhoodOptions = [];
      _loadingNeighborhoods = districtId != null;
    });
    if (districtId == null) return;
    try {
      final neighborhoods = await widget.fetchNeighborhoods(districtId);
      if (!widget.isMounted()) return;
      _updateState(() {
        _neighborhoodOptions = neighborhoods;
        _loadingNeighborhoods = false;
      });
    } catch (_) {
      if (!widget.isMounted()) return;
      _updateState(() => _loadingNeighborhoods = false);
    }
  }

  Future<void> _submit() async {
    final venueId = _selectedVenueId;
    if (venueId == null) return;
    final message = await _showNoteDialog();
    if (!mounted || message == null) return;
    await Future<void>.delayed(Duration(milliseconds: 16));
    if (!mounted) return;
    Navigator.of(
      context,
    ).pop(VenueRequestPayload(venueId: venueId, message: message));
  }

  Future<String?> _showNoteDialog() {
    var noteDraft = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.navBlueDeep,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Basvuru Notu (Opsiyonel)',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      minLines: 3,
                      maxLines: 5,
                      onChanged: (value) {
                        noteDraft = value;
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Istersen kisa bir not ekleyebilirsin (zorunlu degil).',
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: Text('Vazgec'),
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(
                              dialogContext,
                            ).pop(noteDraft.trim()),
                            child: Text('Gonder'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<VenueOption> _filteredVenues() {
    final selectedCityName = _nameById(widget.cities, _selectedCityId);
    final selectedDistrictName = _nameById(
      _districtOptions,
      _selectedDistrictId,
    );
    final selectedNeighborhoodName = _nameById(
      _neighborhoodOptions,
      _selectedNeighborhoodId,
    );
    return widget.allVenues.where((venue) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          venue.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCity =
          _selectedCityId == null ||
          venue.cityId == _selectedCityId ||
          (selectedCityName != null &&
              venue.cityName?.toLowerCase() == selectedCityName);
      final matchesDistrict =
          _selectedDistrictId == null ||
          venue.districtId == _selectedDistrictId ||
          (selectedDistrictName != null &&
              venue.districtName?.toLowerCase() == selectedDistrictName);
      final matchesNeighborhood =
          _selectedNeighborhoodId == null ||
          venue.neighborhoodId == _selectedNeighborhoodId ||
          (selectedNeighborhoodName != null &&
              venue.neighborhoodName?.toLowerCase() ==
                  selectedNeighborhoodName);
      return matchesSearch &&
          matchesCity &&
          matchesDistrict &&
          matchesNeighborhood;
    }).toList();
  }

  String? _nameById(List<VenueLookupOption> list, String? id) {
    if (id == null) return null;
    for (final item in list) {
      if (item.id == id) return item.name.toLowerCase();
    }
    return null;
  }

  void _resetFilters() {
    _updateState(() {
      _selectedCityId = null;
      _selectedDistrictId = null;
      _selectedNeighborhoodId = null;
      _districtOptions = [];
      _neighborhoodOptions = [];
    });
  }
}
