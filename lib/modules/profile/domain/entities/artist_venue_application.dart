class ArtistVenueApplication {
  final String id;
  final String musicianProfileId;
  final String venueId;
  final String musicianStageName;
  final String venueName;
  final String? message;
  final String status;
  final String requestByType;
  final String createdAt;

  const ArtistVenueApplication({
    required this.id,
    required this.musicianProfileId,
    required this.venueId,
    required this.musicianStageName,
    required this.venueName,
    required this.message,
    required this.status,
    required this.requestByType,
    required this.createdAt,
  });
}
