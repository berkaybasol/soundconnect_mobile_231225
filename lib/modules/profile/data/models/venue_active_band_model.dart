import '../../domain/entities/venue_active_band.dart';

class VenueActiveBandModel extends VenueActiveBand {
  const VenueActiveBandModel({
    required super.bandId,
    required super.displayName,
    required super.profileImageUrl,
  });

  factory VenueActiveBandModel.fromJson(Map<String, dynamic> json) {
    return VenueActiveBandModel(
      bandId: json['bandId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? 'Band',
      profileImageUrl: json['profileImageUrl']?.toString(),
    );
  }
}
