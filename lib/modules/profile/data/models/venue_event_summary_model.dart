import '../../../../shared/event_performer_identity.dart';
import '../../domain/entities/venue_event_summary.dart';

class VenueEventSummaryModel extends VenueEventSummary {
  const VenueEventSummaryModel({
    required super.eventId,
    required super.title,
    required super.posterImage,
    required super.performerName,
    required super.musicianProfileId,
    super.bandId,
    required super.performerType,
    required super.eventDate,
    required super.startTime,
    required super.endTime,
  });

  factory VenueEventSummaryModel.fromJson(Map<String, dynamic> json) {
    final performerIdentity = EventPerformerIdentity.fromWire(
      performerType: json['performerType'],
      musicianProfileId: json['musicianProfileId'],
      bandId: json['bandId'],
    );
    return VenueEventSummaryModel(
      eventId: json['eventId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      posterImage: json['posterImage']?.toString(),
      performerName: json['performerName']?.toString() ?? 'Performer',
      musicianProfileId: performerIdentity.musicianProfileId,
      bandId: performerIdentity.bandId,
      performerType: performerIdentity.performerType,
      eventDate: DateTime.tryParse(json['eventDate']?.toString() ?? ''),
      startTime: json['startTime']?.toString(),
      endTime: json['endTime']?.toString(),
    );
  }
}
