import '../../../../shared/event_performer_identity.dart';

class VenueEventDetail {
  final String id;
  final String? shareUrl;
  final String? posterImage;
  final String? performerName;
  final String? musicianProfileId;
  final String? bandId;
  final String performerType;
  final String? title;
  final String? description;
  final DateTime? eventDate;
  final String? startTime;
  final String? endTime;
  final String? venueId;
  final String? venueName;
  final String? venueCity;
  final String? venueDistrict;
  final String? venueNeighborhood;

  const VenueEventDetail({
    required this.id,
    required this.shareUrl,
    required this.posterImage,
    required this.performerName,
    required this.musicianProfileId,
    this.bandId,
    this.performerType = 'MANUAL',
    this.title,
    this.description,
    this.eventDate,
    this.startTime,
    this.endTime,
    this.venueId,
    this.venueName,
    this.venueCity,
    this.venueDistrict,
    this.venueNeighborhood,
  });

  EventPerformerIdentity get performerIdentity =>
      EventPerformerIdentity.fromWire(
        performerType: performerType,
        musicianProfileId: musicianProfileId,
        bandId: bandId,
      );
}
