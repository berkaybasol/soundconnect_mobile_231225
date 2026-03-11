class ArtistVenueConnectionResponse {
  final String id;
  final String musicianProfileId;
  final String venueId;
  final String? musicianStageName;
  final String? venueName;
  final String? message;
  final String? status;
  final String? requestByType;
  final String? createdAt;

  const ArtistVenueConnectionResponse({
    required this.id,
    required this.musicianProfileId,
    required this.venueId,
    this.musicianStageName,
    this.venueName,
    this.message,
    this.status,
    this.requestByType,
    this.createdAt,
  });

  factory ArtistVenueConnectionResponse.fromJson(Map<String, dynamic> json) {
    return ArtistVenueConnectionResponse(
      id: json['id']?.toString() ?? '',
      musicianProfileId: json['musicianProfileId']?.toString() ?? '',
      venueId: json['venueId']?.toString() ?? '',
      musicianStageName: json['musicianStageName']?.toString(),
      venueName: json['venueName']?.toString(),
      message: json['message']?.toString(),
      status: json['status']?.toString(),
      requestByType: json['requestByType']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}
