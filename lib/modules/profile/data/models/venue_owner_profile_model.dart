import '../../domain/entities/venue_owner_profile.dart';
import 'venue_active_band_model.dart';
import 'venue_active_musician_model.dart';
import 'venue_event_summary_model.dart';

class VenueOwnerProfileModel extends VenueOwnerProfile {
  const VenueOwnerProfileModel({
    required super.venueProfileId,
    required super.venueId,
    required super.ownerUserId,
    required super.venueName,
    required super.bio,
    required super.profilePictureUrl,
    required super.instagramUrl,
    required super.youtubeUrl,
    required super.websiteUrl,
    required super.address,
    required super.phone,
    required super.website,
    required super.description,
    required super.musicStartTime,
    required super.cityId,
    required super.cityName,
    required super.districtId,
    required super.districtName,
    required super.neighborhoodId,
    required super.neighborhoodName,
    required super.status,
    required super.activeMusicians,
    required super.activeBands,
    required super.weeklyEvents,
  });

  factory VenueOwnerProfileModel.fromJson(Map<String, dynamic> json) {
    return VenueOwnerProfileModel(
      venueProfileId: json['venueProfileId']?.toString() ?? '',
      venueId: json['venueId']?.toString() ?? '',
      ownerUserId: json['ownerUserId']?.toString() ?? '',
      venueName: json['venueName']?.toString() ?? '',
      bio: json['bio']?.toString(),
      profilePictureUrl: json['profilePictureUrl']?.toString(),
      instagramUrl: json['instagramUrl']?.toString(),
      youtubeUrl: json['youtubeUrl']?.toString(),
      websiteUrl: json['websiteUrl']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      website: json['website']?.toString(),
      description: json['description']?.toString(),
      musicStartTime: json['musicStartTime']?.toString(),
      cityId: json['cityId']?.toString(),
      cityName: json['cityName']?.toString(),
      districtId: json['districtId']?.toString(),
      districtName: json['districtName']?.toString(),
      neighborhoodId: json['neighborhoodId']?.toString(),
      neighborhoodName: json['neighborhoodName']?.toString(),
      status: json['status']?.toString(),
      activeMusicians: _musicians(json['activeMusicians']),
      activeBands: _bands(json['activeBands']),
      weeklyEvents: _events(json['weeklyEvents']),
    );
  }

  static List<VenueActiveMusicianModel> _musicians(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(VenueActiveMusicianModel.fromJson)
        .toList();
  }

  static List<VenueEventSummaryModel> _events(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(VenueEventSummaryModel.fromJson)
        .toList();
  }

  static List<VenueActiveBandModel> _bands(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(VenueActiveBandModel.fromJson)
        .toList();
  }
}
