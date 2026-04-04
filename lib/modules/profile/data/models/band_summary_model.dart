import '../../domain/entities/band_summary.dart';

class BandSummaryModel extends BandSummary {
  const BandSummaryModel({
    required super.id,
    required super.name,
    required super.description,
    required super.profilePictureUrl,
  });

  factory BandSummaryModel.fromJson(Map<String, dynamic> json) {
    return BandSummaryModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? '',
      description: json['description']?.toString(),
      profilePictureUrl: json['profilePictureUrl']?.toString() ??
          json['profilePicture']?.toString(),
    );
  }
}
