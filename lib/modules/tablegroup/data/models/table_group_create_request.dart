class TableGroupCreateRequest {
  final String? venueId;
  final String? venueName;
  final int maxPersonCount;
  final List<String> genderPrefs;
  final int ageMin;
  final int ageMax;
  final DateTime expiresAt;
  final String cityId;
  final String? districtId;
  final String? neighborhoodId;

  const TableGroupCreateRequest({
    required this.venueId,
    required this.venueName,
    required this.maxPersonCount,
    required this.genderPrefs,
    required this.ageMin,
    required this.ageMax,
    required this.expiresAt,
    required this.cityId,
    required this.districtId,
    required this.neighborhoodId,
  });

  Map<String, dynamic> toJson() {
    return {
      'venueId': venueId,
      'venueName': venueName,
      'maxPersonCount': maxPersonCount,
      'genderPrefs': genderPrefs,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'expiresAt': expiresAt.toIso8601String(),
      'cityId': cityId,
      'districtId': districtId,
      'neighborhoodId': neighborhoodId,
    };
  }
}
