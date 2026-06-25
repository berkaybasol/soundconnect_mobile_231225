part of 'venue_profile_screen.dart';

extension _VenueProfileViewStateVenueActions
    on _MusicianPublicProfileViewState {
  Future<void> _ensureFallbackWeeklyEvents(VenueOwnerProfile profile) async {
    final venueId = profile.venueId.trim();
    if (venueId.isEmpty) return;
    if (profile.weeklyEvents.isNotEmpty) {
      if (_fallbackWeeklyEvents.isNotEmpty ||
          _fallbackWeeklyEventsVenueId != null) {
        _updateState(() {
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
    if (_fallbackWeeklyEventsVenueId == venueId) {
      return;
    }

    _fallbackWeeklyEventsVenueId = venueId;
    _loadingFallbackWeeklyEvents = true;
    try {
      final result = await _venueEventRepository.listByVenue(venueId);
      final items = result.data ?? const <VenueOwnerEventItem>[];
      if (!mounted) return;
      _updateState(() {
        _fallbackWeeklyEvents = items
            .map((item) => _toWeeklyCalendarEvent(profile, item))
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      _updateState(() {
        _fallbackWeeklyEvents = const [];
        _fallbackWeeklyEventsVenueId = venueId;
      });
    } finally {
      _loadingFallbackWeeklyEvents = false;
    }
  }
}
