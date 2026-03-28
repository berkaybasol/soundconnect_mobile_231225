import '../../domain/entities/venue_profile_summary.dart';

class VenueProfileSummaryModel extends VenueProfileSummary {
  const VenueProfileSummaryModel({
    required super.id,
    required super.venueId,
    required super.venueName,
  });

  factory VenueProfileSummaryModel.fromJson(Map<String, dynamic> json) {
    return VenueProfileSummaryModel(
      id: json['id']?.toString() ?? '',
      venueId: json['venueId']?.toString() ?? '',
      venueName: json['venueName']?.toString() ?? '',
    );
  }
}
