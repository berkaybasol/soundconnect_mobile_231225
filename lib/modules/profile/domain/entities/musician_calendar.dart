import 'venue_event_detail.dart';

class MusicianCalendarSettings {
  const MusicianCalendarSettings({
    required this.visible,
    required this.version,
  });

  final bool visible;
  final int version;
}

class MusicianCalendarPage {
  MusicianCalendarPage({
    required this.profileId,
    required this.visible,
    required this.startDate,
    required this.endDate,
    required List<VenueEventDetail> events,
    required this.page,
    required this.size,
    required this.hasNext,
  }) : events = List.unmodifiable(events);

  final String profileId;
  final bool visible;
  final DateTime startDate;
  final DateTime endDate;
  final List<VenueEventDetail> events;
  final int page;
  final int size;
  final bool hasNext;
}
