part of 'profile_venue_request_sheet.dart';

extension _VenueRequestSheetStateActions on _VenueRequestSheetState {
  Future<void> _onCityChanged(String? cityId) async {
    if (!mounted || !widget.isMounted()) return;
    final generation = ++_districtGeneration;
    _neighborhoodGeneration++;
    _updateState(() {
      _selectedCityId = cityId;
      _selectedDistrictId = null;
      _selectedNeighborhoodId = null;
      _districtOptions = [];
      _neighborhoodOptions = [];
      _loadingDistricts = cityId != null;
      _loadingNeighborhoods = false;
      _selectedVenueId = null;
      _lookupError = null;
    });
    if (cityId == null) return;
    try {
      final districts = await widget.fetchDistricts(cityId);
      if (!mounted ||
          !widget.isMounted() ||
          generation != _districtGeneration) {
        return;
      }
      _updateState(() {
        _districtOptions = districts;
        _loadingDistricts = false;
      });
    } catch (_) {
      if (!mounted ||
          !widget.isMounted() ||
          generation != _districtGeneration) {
        return;
      }
      _updateState(() {
        _loadingDistricts = false;
        _lookupError =
            'İlçeler getirilemedi. Şehri yeniden seçerek tekrar dene.';
      });
    }
  }

  Future<void> _onDistrictChanged(String? districtId) async {
    if (!mounted || !widget.isMounted()) return;
    final generation = ++_neighborhoodGeneration;
    _updateState(() {
      _selectedDistrictId = districtId;
      _selectedNeighborhoodId = null;
      _neighborhoodOptions = [];
      _loadingNeighborhoods = districtId != null;
      _selectedVenueId = null;
      _lookupError = null;
    });
    if (districtId == null) return;
    try {
      final neighborhoods = await widget.fetchNeighborhoods(districtId);
      if (!mounted ||
          !widget.isMounted() ||
          generation != _neighborhoodGeneration) {
        return;
      }
      _updateState(() {
        _neighborhoodOptions = neighborhoods;
        _loadingNeighborhoods = false;
      });
    } catch (_) {
      if (!mounted ||
          !widget.isMounted() ||
          generation != _neighborhoodGeneration) {
        return;
      }
      _updateState(() {
        _loadingNeighborhoods = false;
        _lookupError =
            'Semtler getirilemedi. İlçeyi yeniden seçerek tekrar dene.';
      });
    }
  }

  Future<void> _submit() async {
    if (!mounted || !widget.isMounted() || _submitting) return;
    final venueId = _selectedVenueId;
    if (venueId == null ||
        !_filteredVenues().any((venue) => venue.id == venueId)) {
      return;
    }
    final origin = ModalRoute.of(context);
    _updateState(() => _submitting = true);
    try {
      final message = await _showNoteDialog();
      if (!mounted ||
          !widget.isMounted() ||
          message == null ||
          origin?.isCurrent == false) {
        return;
      }
      Navigator.of(
        context,
      ).pop(VenueRequestPayload(venueId: venueId, message: message));
    } finally {
      _updateState(() => _submitting = false);
    }
  }

  Future<String?> _showNoteDialog() {
    var noteDraft = '';
    var decisionDelivered = false;
    final noteForm = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        void decide({required bool send}) {
          if (decisionDelivered ||
              !dialogContext.mounted ||
              ModalRoute.of(dialogContext)?.isCurrent != true) {
            return;
          }
          if (send && noteForm.currentState?.validate() != true) {
            return;
          }
          decisionDelivered = true;
          Navigator.of(dialogContext).pop(send ? noteDraft.trim() : null);
        }

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
              child: Form(
                key: noteForm,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İstek notu (isteğe bağlı)',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        minLines: 3,
                        maxLines: 5,
                        validator: (value) => (value?.trim().length ?? 0) > 255
                            ? 'Not en fazla 255 karakter olabilir.'
                            : null,
                        onChanged: (value) {
                          noteDraft = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'İstersen kısa bir not ekleyebilirsin.',
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => decide(send: false),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Text('Vazgeç'),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: GradientOutlineButton(
                              onPressed: () => decide(send: true),
                              strokeWidth: 1,
                              horizontalPadding: 12,
                              label: 'Gönder',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
    _districtGeneration++;
    _neighborhoodGeneration++;
    _updateState(() {
      _loadingDistricts = false;
      _loadingNeighborhoods = false;
      _selectedVenueId = null;
      _lookupError = null;
      _selectedCityId = null;
      _selectedDistrictId = null;
      _selectedNeighborhoodId = null;
      _districtOptions = [];
      _neighborhoodOptions = [];
    });
  }
}
