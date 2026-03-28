import '../../domain/entities/venue_public_profile.dart';
import 'venue_active_musician_model.dart';
import 'venue_event_summary_model.dart';

class VenuePublicProfileModel extends VenuePublicProfile {
  const VenuePublicProfileModel({
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
    required super.cityName,
    required super.districtName,
    required super.neighborhoodName,
    required super.activeMusicians,
    required super.weeklyEvents,
  });

  factory VenuePublicProfileModel.fromJson(Map<String, dynamic> json) {
    return VenuePublicProfileModel(
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
      cityName: json['cityName']?.toString(),
      districtName: json['districtName']?.toString(),
      neighborhoodName: json['neighborhoodName']?.toString(),
      activeMusicians: _musicians(json['activeMusicians']),
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
}
