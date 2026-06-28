import '../../domain/entities/studio_profile.dart';

class StudioProfileModel extends StudioProfile {
  const StudioProfileModel({
    required super.id,
    required super.userId,
    required super.name,
    required super.description,
    required super.profilePictureMediaId,
    required super.profilePictureUrl,
    required super.address,
    required super.phone,
    required super.website,
    required super.facilities,
    required super.instagramUrl,
    required super.youtubeUrl,
  });

  factory StudioProfileModel.fromJson(Map<String, dynamic> json) {
    final rawFacilities = json['facilities'];
    return StudioProfileModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      name: _stringOrNull(json['name']),
      description: _stringOrNull(json['description']),
      profilePictureMediaId: _stringOrNull(json['profilePictureMediaId']),
      profilePictureUrl: _stringOrNull(json['profilePictureUrl']),
      address: _stringOrNull(json['address'] ?? json['adress']),
      phone: _stringOrNull(json['phone']),
      website: _stringOrNull(json['website']),
      facilities: rawFacilities is List
          ? rawFacilities
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList()
          : const [],
      instagramUrl: _stringOrNull(json['instagramUrl']),
      youtubeUrl: _stringOrNull(json['youtubeUrl']),
    );
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
