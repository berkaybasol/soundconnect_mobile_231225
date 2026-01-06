class LocationEndpoints {
  static const String cityBase = '/api/v1/cities';
  static const String districtBase = '/api/v1/districts';
  static const String neighborhoodBase = '/api/v1/neighborhoods';

  static const String getAllCities = '$cityBase/get-all-cities';
  static String getDistrictsByCity(String cityId) =>
      '$districtBase/get-by-city/$cityId';
  static String getNeighborhoodsByDistrict(String districtId) =>
      '$neighborhoodBase/get-by-district/$districtId';
}
