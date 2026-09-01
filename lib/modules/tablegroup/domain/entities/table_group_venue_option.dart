class TableGroupVenueOption {
  const TableGroupVenueOption({
    required this.id,
    required this.name,
    required this.profilePictureUrl,
    required this.address,
    required this.cityId,
    required this.cityName,
    required this.districtId,
    required this.districtName,
    required this.neighborhoodId,
    required this.neighborhoodName,
  });

  final String id;
  final String name;
  final String? profilePictureUrl;
  final String address;
  final String cityId;
  final String cityName;
  final String districtId;
  final String districtName;
  final String neighborhoodId;
  final String neighborhoodName;

  String get locationSummary => '$neighborhoodName, $districtName, $cityName';
}
