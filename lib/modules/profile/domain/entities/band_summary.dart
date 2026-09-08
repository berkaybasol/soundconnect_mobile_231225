class BandSummary {
  final String id;
  final String name;
  final String? description;
  final String? profilePictureUrl;
  final bool? countsTowardCreationLimit;

  const BandSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.profilePictureUrl,
    this.countsTowardCreationLimit,
  });
}
