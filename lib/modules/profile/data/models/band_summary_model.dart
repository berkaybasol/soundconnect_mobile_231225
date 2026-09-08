import '../../domain/entities/band_summary.dart';

class BandSummaryModel extends BandSummary {
  const BandSummaryModel({
    required super.id,
    required super.name,
    required super.description,
    required super.profilePictureUrl,
    super.countsTowardCreationLimit,
  });

  factory BandSummaryModel.fromJson(Map<String, dynamic> json) {
    return BandSummaryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? '',
      countsTowardCreationLimit: json['countsTowardCreationLimit'] is bool
          ? json['countsTowardCreationLimit'] as bool
          : null,
      description: json['description']?.toString(),
      profilePictureUrl:
          json['profilePictureUrl']?.toString() ??
          json['profilePicture']?.toString(),
    );
  }
}
