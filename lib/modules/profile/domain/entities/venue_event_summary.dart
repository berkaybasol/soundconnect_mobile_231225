class VenueEventSummary {
  final String eventId;
  final String title;
  final String? posterImage;
  final String performerName;
  final String? musicianProfileId;
  final String performerType;
  final DateTime? eventDate;
  final String? startTime;
  final String? endTime;

  const VenueEventSummary({
    required this.eventId,
    required this.title,
    required this.posterImage,
    required this.performerName,
    required this.musicianProfileId,
    required this.performerType,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
  });
}
