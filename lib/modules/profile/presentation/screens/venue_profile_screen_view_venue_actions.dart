// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously, invalid_use_of_protected_member

part of 'venue_profile_screen.dart';

extension _VenueProfileViewStateVenueActions
    on _MusicianPublicProfileViewState {
  Future<void> _ensureFallbackWeeklyEvents(VenueOwnerProfile profile) async {
    final venueId = profile.venueId.trim();
    if (venueId.isEmpty) return;
    if (profile.weeklyEvents.isNotEmpty) {
      if (_fallbackWeeklyEvents.isNotEmpty ||
          _fallbackWeeklyEventsVenueId != null) {
        setState(() {
          _fallbackWeeklyEvents = const [];
          _fallbackWeeklyEventsVenueId = null;
        });
      }
      return;
    }
    if (_loadingFallbackWeeklyEvents &&
        _fallbackWeeklyEventsVenueId == venueId) {
      return;
    }
    if (_fallbackWeeklyEventsVenueId == venueId &&
        _fallbackWeeklyEvents.isNotEmpty) {
      return;
    }

    _loadingFallbackWeeklyEvents = true;
    try {
      final result = await _venueEventRepository.listByVenue(venueId);
      final items = result.data ?? const <VenueOwnerEventItem>[];
      if (!mounted) return;
      setState(() {
        _fallbackWeeklyEvents = items
            .map((item) => _toWeeklyCalendarEvent(profile, item))
            .toList();
        _fallbackWeeklyEventsVenueId = venueId;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fallbackWeeklyEvents = const [];
        _fallbackWeeklyEventsVenueId = venueId;
      });
    } finally {
      _loadingFallbackWeeklyEvents = false;
    }
  }

  Future<void> _editVenues(String profileId) async {
    try {
      final acceptedIntro =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => const VenueIntroScreen(),
            ),
          ) ??
          false;
      if (!acceptedIntro || !mounted) return;

      final allVenues = await _fetchAllVenues();
      final cities = await _fetchCities();
      final accepted = await _fetchAcceptedVenueConnections(profileId);
      final pending = await _fetchPendingVenueConnections(profileId);

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

      final requestResult = await _artistVenueRepository.createArtistRequest(
        musicianProfileId: profileId,
        venueId: selected.venueId,
        message: selected.message,
      );
      if (!requestResult.isSuccess) {
        throw requestResult.error?.message ?? 'Request failed';
      }

      if (!mounted) return;
      await context.read<ArtistVenueConnectionsCubit>().loadAcceptedVenues(
        profileId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mekan baglanti istegi gonderildi (onay bekliyor).'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Mekanlar guncellenemedi: $e')));
    }
  }
}
