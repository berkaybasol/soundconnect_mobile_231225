class EventEndpoints {
  static const String base = '/api/v1/events';
  static const String today = '$base/today';
  static String byCity(String cityId) => '$base/city/$cityId';
  static String byDistrict(String districtId) => '$base/district/$districtId';
  static String byNeighborhood(String neighborhoodId) =>
      '$base/neighborhood/$neighborhoodId';
  static String byVenue(String venueId) => '$base/venue/$venueId';
}
