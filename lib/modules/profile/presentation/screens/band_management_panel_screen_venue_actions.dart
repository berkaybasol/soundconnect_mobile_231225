part of 'band_management_panel_screen.dart';

extension _BandManagementPanelScreenStateVenueActions
    on _BandManagementPanelScreenState {
  Future<void> _editBandVenues() async {
    final session = ProfileActionSession(
      roles: const ['MUSICIAN', 'ROLE_MUSICIAN'],
    );
    final bandId = _profile.id;
    bool current() => mounted && session.isCurrent && _profile.id == bandId;
    if (_submitting || !mounted || !session.isCurrent) return;
    _updateState(() => _submitting = true);
    try {
      if (await shouldShowVenueConnectionIntro()) {
        if (!mounted || !session.isCurrent) return;
        final acceptedIntro =
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => VenueIntroScreen(),
              ),
            ) ??
            false;
        if (!acceptedIntro || !mounted || !session.isCurrent) return;
      }
      if (!mounted || !session.isCurrent) return;
      final allVenues = await _fetchAllVenues();
      if (!mounted || !session.isCurrent) return;
      final cities = await _fetchCities();
      if (!mounted || !session.isCurrent) return;
      final accepted = await _fetchBandVenueConnectionsByStatus(
        _profile.id,
        status: 'ACCEPTED',
      );
      if (!mounted || !session.isCurrent) return;
      final pending = await _fetchBandVenueConnectionsByStatus(
        _profile.id,
        status: 'PENDING',
      );
      if (!mounted || !session.isCurrent) return;

      final selected = await showVenueRequestBottomSheet(
        context: context,
        allVenues: allVenues,
        cities: cities,
        acceptedIds: accepted.map((item) => item.venueId).toSet(),
        pendingIds: pending.map((item) => item.venueId).toSet(),
        fetchDistricts: _fetchDistricts,
        fetchNeighborhoods: _fetchNeighborhoods,
        isMounted: current,
      );
      if (selected == null || !mounted || !session.isCurrent) return;

      final requestResult = await _artistVenueRepository.createBandRequest(
        bandId: bandId,
        venueId: selected.venueId,
        message: selected.message,
        expectedSessionKey: session.userId,
      );
      if (!mounted || !session.isCurrent) return;
      if (!requestResult.isSuccess) {
        throw requestResult.error?.message ?? 'Request failed';
      }
      if (!mounted || !session.isCurrent) return;

      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          content: const Text('Band adına mekan bağlantı isteği gönderildi.'),
        ),
      );
    } catch (e) {
      if (!mounted || !session.isCurrent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.error,
          content: Text('Band mekanları güncellenemedi: $e'),
        ),
      );
    } finally {
      if (mounted) {
        _updateState(() => _submitting = false);
      }
    }
  }

  Future<List<VenueOption>> _fetchAllVenues() async {
    final result = await _venueDirectoryRepository.getAllVenues();
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'Mekanlar getirilemedi.';
    }
    return result.data ?? const [];
  }

  Future<List<VenueLookupOption>> _fetchCities() async {
    final result = await _locationRepository.getCities();
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'Şehirler getirilemedi.';
    }
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchDistricts(String cityId) async {
    final result = await _locationRepository.getDistricts(cityId);
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'İlçeler getirilemedi.';
    }
    return (result.data ?? const [])
        .map((item) => VenueLookupOption(id: item.id, name: item.name))
        .toList();
  }

  Future<List<VenueLookupOption>> _fetchNeighborhoods(String districtId) async {
    final result = await _locationRepository.getNeighborhoods(districtId);
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'Semtler getirilemedi.';
    }
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
    if (!result.isSuccess || result.data == null) {
      throw result.error?.message ?? 'Mekan bağlantıları getirilemedi.';
    }
    return result.data ?? const [];
  }
}
