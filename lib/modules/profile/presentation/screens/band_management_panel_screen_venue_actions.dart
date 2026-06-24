part of 'band_management_panel_screen.dart';

extension _BandManagementPanelScreenStateVenueActions
    on _BandManagementPanelScreenState {
  Future<void> _editBandVenues() async {
    if (_submitting) return;
    _updateState(() => _submitting = true);
    try {
      if (await shouldShowVenueConnectionIntro()) {
        final acceptedIntro =
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => VenueIntroScreen(),
              ),
            ) ??
            false;
        if (!acceptedIntro || !mounted) return;
      }

      final allVenues = await _fetchAllVenues();
      final cities = await _fetchCities();
      final accepted = await _fetchBandVenueConnectionsByStatus(
        _profile.id,
        status: 'ACCEPTED',
      );
      final pending = await _fetchBandVenueConnectionsByStatus(
        _profile.id,
        status: 'PENDING',
      );
      if (!mounted) return;

      final selected = await showVenueRequestBottomSheet(
        context: context,
        allVenues: allVenues,
        cities: cities,
        acceptedIds: accepted.map((item) => item.venueId).toSet(),
        pendingIds: pending.map((item) => item.venueId).toSet(),
        fetchDistricts: _fetchDistricts,
        fetchNeighborhoods: _fetchNeighborhoods,
        isMounted: () => mounted,
      );
      if (selected == null) return;

      final requestResult = await _artistVenueRepository.createBandRequest(
        bandId: _profile.id,
        venueId: selected.venueId,
        message: selected.message,
      );
      if (!requestResult.isSuccess) {
        throw requestResult.error?.message ?? 'Request failed';
      }
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Band adına mekan bağlantı isteği gönderildi.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Band mekanları güncellenemedi: $e')),
      );
    } finally {
      if (mounted) {
        _updateState(() => _submitting = false);
      }
    }
  }

  Future<List<VenueOption>> _fetchAllVenues() async {
    final result = await _venueDirectoryRepository.getAllVenues();
    return result.data ?? const [];
  }

  Future<List<VenueLookupOption>> _fetchCities() async {
    final result = await _locationRepository.getCities();
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchDistricts(String cityId) async {
    final result = await _locationRepository.getDistricts(cityId);
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchNeighborhoods(String districtId) async {
    final result = await _locationRepository.getNeighborhoods(districtId);
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueConnection>> _fetchBandVenueConnectionsByStatus(
    String bandId, {
    required String status,
  }) async {
    final result = await _artistVenueRepository.getVenueConnectionsByBandStatus(
      bandId,
      status: status,
    );
    return result.data ?? const [];
  }
}
