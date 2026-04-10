class ArtistVenueConnectionResponse {
  final String id;
  final String musicianProfileId;
  final String bandId;
  final String venueId;
  final String? musicianStageName;
  final String? bandName;
  final String? bandProfilePictureUrl;
  final String? venueProfilePictureUrl;
  final String? venueName;
  final String? message;
  final String? status;
  final String? requestByType;
  final String? createdAt;

  const ArtistVenueConnectionResponse({
    required this.id,
    required this.musicianProfileId,
    required this.bandId,
    required this.venueId,
    this.musicianStageName,
    this.bandName,
    this.bandProfilePictureUrl,
    this.venueProfilePictureUrl,
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
      bandId: json['bandId']?.toString() ?? '',
      venueId: json['venueId']?.toString() ?? '',
      musicianStageName: json['musicianStageName']?.toString(),
      bandName: json['bandName']?.toString(),
      bandProfilePictureUrl: json['bandProfilePictureUrl']?.toString(),
      venueProfilePictureUrl:
          json['venueProfilePictureUrl']?.toString() ??
          json['venueProfileImageUrl']?.toString() ??
          json['venueProfilePicture']?.toString() ??
          json['venueImageUrl']?.toString() ??
          json['venueImage']?.toString() ??
          json['profilePictureUrl']?.toString() ??
          json['profilePicture']?.toString() ??
          json['imageUrl']?.toString(),
      venueName: json['venueName']?.toString(),
      message: json['message']?.toString(),
      status: json['status']?.toString(),
      requestByType: json['requestByType']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}
