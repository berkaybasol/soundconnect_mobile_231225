import '../../domain/entities/band_member_summary.dart';

class BandMemberSummaryModel extends BandMemberSummary {
  const BandMemberSummaryModel({
    required super.userId,
    required super.profileId,
    required super.username,
    required super.profilePictureUrl,
    required super.role,
    required super.status,
  });

  factory BandMemberSummaryModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? musicianProfile =
        json['musicianProfile'] is Map<String, dynamic>
        ? json['musicianProfile'] as Map<String, dynamic>
        : null;

    return BandMemberSummaryModel(
      userId: json['userId']?.toString() ?? '',
      profileId: _firstNonEmpty(<Object?>[
        json['profileId'],
        json['musicianProfileId'],
        musicianProfile?['id'],
        musicianProfile?['profileId'],
      ]),
      username: json['username']?.toString() ?? '',
      profilePictureUrl: _firstNonEmpty(<Object?>[
        json['profilePictureUrl'],
        json['profilePicture'],
        json['profileImageUrl'],
        json['imageUrl'],
        json['avatarUrl'],
        json['photoUrl'],
        json['photo'],
        musicianProfile?['profilePictureUrl'],
        musicianProfile?['profilePicture'],
        musicianProfile?['profileImageUrl'],
        musicianProfile?['imageUrl'],
        musicianProfile?['avatarUrl'],
        musicianProfile?['photoUrl'],
        musicianProfile?['photo'],
      ]),
      role: json['role']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  static String? _firstNonEmpty(List<Object?> candidates) {
    for (final Object? candidate in candidates) {
      final String? parsed = _stringValue(candidate);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    }
    return null;
  }

  static String? _stringValue(Object? value) {
    if (value == null) return null;
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is Map<String, dynamic>) {
      return _firstNonEmpty(<Object?>[
        value['url'],
        value['href'],
        value['src'],
        value['value'],
        value['path'],
      ]);
    }
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
