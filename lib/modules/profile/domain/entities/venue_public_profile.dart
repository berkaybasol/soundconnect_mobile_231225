import 'venue_active_band.dart';
import 'venue_active_musician.dart';
import 'venue_event_summary.dart';

class VenuePublicProfile {
  final String venueProfileId;
  final String venueId;
  final String ownerUserId;
  final String venueName;
  final String? bio;
  final String? profilePictureUrl;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? websiteUrl;
  final String? address;
  final String? phone;
  final String? website;
  final String? description;
  final String? musicStartTime;
  final String? cityName;
  final String? districtName;
  final String? neighborhoodName;
  final List<VenueActiveMusician> activeMusicians;
  final List<VenueActiveBand> activeBands;
  final List<VenueEventSummary> weeklyEvents;

  const VenuePublicProfile({
    required this.venueProfileId,
    required this.venueId,
    required this.ownerUserId,
    required this.venueName,
    required this.bio,
    required this.profilePictureUrl,
    required this.instagramUrl,
    required this.youtubeUrl,
    required this.websiteUrl,
    required this.address,
    required this.phone,
    required this.website,
    required this.description,
    required this.musicStartTime,
    required this.cityName,
    required this.districtName,
    required this.neighborhoodName,
    required this.activeMusicians,
    required this.activeBands,
    required this.weeklyEvents,
  });
}
