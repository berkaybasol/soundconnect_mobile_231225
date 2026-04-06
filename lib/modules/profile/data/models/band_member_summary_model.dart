import '../../domain/entities/band_member_summary.dart';

class BandMemberSummaryModel extends BandMemberSummary {
  const BandMemberSummaryModel({
    required super.userId,
    required super.username,
    required super.profilePictureUrl,
    required super.role,
    required super.status,
  });

  factory BandMemberSummaryModel.fromJson(Map<String, dynamic> json) {
    return BandMemberSummaryModel(
      userId: json['userId']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      profilePictureUrl:
          json['profilePictureUrl']?.toString() ??
          json['profilePicture']?.toString(),
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }
}
