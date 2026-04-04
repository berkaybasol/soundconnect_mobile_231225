class ArtistVenueConnectionEndpoints {
  static const String base = '/api/v1/artist-venue-connections';

  static String byMusician(String musicianProfileId, {String? status}) {
    if (status == null || status.isEmpty) {
      return '$base/musician/$musicianProfileId';
    }
    return '$base/musician/$musicianProfileId?status=$status';
  }

  static String byVenue(String venueId, {String? status}) {
    if (status == null || status.isEmpty) {
      return '$base/venue/$venueId';
    }
    return '$base/venue/$venueId?status=$status';
  }

  static String request(String requestByType) {
    return '$base/request?requestByType=$requestByType';
  }
}
