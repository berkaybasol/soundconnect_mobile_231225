import 'event_performer_request.dart';

/// Server-side temporal buckets use the SoundConnect event time zone. Keeping
/// filtering on the server preserves page counts and access to older events.
enum EventProfilePublicationPeriod { all, current, future, past }

extension EventProfilePublicationPeriodX on EventProfilePublicationPeriod {
  String get wireValue => name.toUpperCase();
}

/// One profile's independent publication choice for an approved event.
///
/// A musician target can represent a personal performance or a band event the
/// musician is eligible to publish. It never grants publication to other
/// members or changes the performer's participation in the venue's event.
class EventProfilePublication {
  const EventProfilePublication({
    required this.eventId,
    required this.targetType,
    required this.targetId,
    required this.visible,
    required this.version,
    required this.eventTitle,
    required this.eventDate,
    required this.startTime,
    this.endTime,
    this.posterImage,
    required this.venueId,
    required this.venueName,
    required this.performerName,
  });

  final String eventId;
  final EventPerformerTargetType targetType;
  final String targetId;
  final bool visible;
  final int version;
  final String eventTitle;
  final DateTime eventDate;
  final String startTime;
  final String? endTime;
  final String? posterImage;
  final String venueId;
  final String venueName;
  final String performerName;
}

class EventProfilePublicationPage {
  const EventProfilePublicationPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.hasNext,
  });

  final List<EventProfilePublication> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool hasNext;

  bool get isOutOfRange => page > 0 && page >= totalPages;
}
