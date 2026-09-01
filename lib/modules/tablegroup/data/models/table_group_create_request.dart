/// The backend derives the table owner exclusively from the authenticated
/// user principal. Deliberately do not add band/profile/acting-as identifiers
/// to this request.
class TableGroupCreateRequest {
  static const int maxDescriptionLength = 280;

  final String? venueId;
  final String? venueName;
  final String description;
  final int maxPersonCount;
  final List<String> genderPrefs;
  final int ageMin;
  final int ageMax;
  final DateTime meetingAt;
  final String cityId;
  final String? districtId;
  final String? neighborhoodId;

  const TableGroupCreateRequest({
    required this.venueId,
    required this.venueName,
    required this.description,
    required this.maxPersonCount,
    required this.genderPrefs,
    required this.ageMin,
    required this.ageMax,
    required this.meetingAt,
    required this.cityId,
    required this.districtId,
    required this.neighborhoodId,
  });

  bool get hasValidVenueIdentity {
    final hasVenueId = venueId?.trim().isNotEmpty == true;
    final hasVenueName = venueName?.trim().isNotEmpty == true;
    return !(hasVenueId && hasVenueName);
  }

  static String? _trimmedOrNull(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String normalizeDescription(String value) => value.trim();

  static int descriptionCodePointLength(String value) =>
      normalizeDescription(value).runes.length;

  String get normalizedDescription => normalizeDescription(description);

  bool get hasValidDescription =>
      normalizedDescription.isNotEmpty &&
      descriptionCodePointLength(description) <= maxDescriptionLength;

  Map<String, dynamic> toJson() {
    final meetingAtWire = meetingAt.toUtc().toIso8601String();
    return {
      'venueId': _trimmedOrNull(venueId),
      'venueName': _trimmedOrNull(venueName),
      'description': normalizedDescription,
      'maxPersonCount': maxPersonCount,
      'genderPrefs': genderPrefs,
      'ageMin': ageMin,
      'ageMax': ageMax,
      'meetingAt': meetingAtWire,
      // Temporary rolling-deploy bridge: an older backend still consumes
      // the selected gathering time under the expiresAt name.
      'expiresAt': meetingAtWire,
      'cityId': cityId,
      'districtId': districtId,
      'neighborhoodId': neighborhoodId,
    };
  }
}
