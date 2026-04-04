class VenueOption {
  final String id;
  final String name;
  final String? profilePictureUrl;
  final String? cityId;
  final String? districtId;
  final String? neighborhoodId;
  final String? cityName;
  final String? districtName;
  final String? neighborhoodName;

  const VenueOption({
    required this.id,
    required this.name,
    this.profilePictureUrl,
    this.cityId,
    this.districtId,
    this.neighborhoodId,
    this.cityName,
    this.districtName,
    this.neighborhoodName,
  });
}

class VenueLookupOption {
  final String id;
  final String name;

  const VenueLookupOption({required this.id, required this.name});
}

class VenueConnection {
  final String requestId;
  final String venueId;
  final String venueName;

  const VenueConnection({
    required this.requestId,
    required this.venueId,
    required this.venueName,
  });
}

class MusicianConnection {
  final String requestId;
  final String musicianProfileId;
  final String musicianName;

  const MusicianConnection({
    required this.requestId,
    required this.musicianProfileId,
    required this.musicianName,
  });
}
