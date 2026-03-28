import '../../domain/entities/venue_active_musician.dart';

class VenueActiveMusicianModel extends VenueActiveMusician {
  const VenueActiveMusicianModel({
    required super.musicianProfileId,
    required super.displayName,
    required super.profileImageUrl,
  });

  factory VenueActiveMusicianModel.fromJson(Map<String, dynamic> json) {
    return VenueActiveMusicianModel(
      musicianProfileId: json['musicianProfileId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Sanatci',
      profileImageUrl: json['profileImageUrl']?.toString(),
    );
  }
}
