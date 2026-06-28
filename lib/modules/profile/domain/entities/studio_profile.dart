class StudioProfile {
  final String id;
  final String userId;
  final String? name;
  final String? description;
  final String? profilePictureMediaId;
  final String? profilePictureUrl;
  final String? address;
  final String? phone;
  final String? website;
  final List<String> facilities;
  final String? instagramUrl;
  final String? youtubeUrl;

  const StudioProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.profilePictureMediaId,
    required this.profilePictureUrl,
    required this.address,
    required this.phone,
    required this.website,
    required this.facilities,
    required this.instagramUrl,
    required this.youtubeUrl,
  });

  String get displayName {
    final value = name?.trim() ?? '';
    return value.isEmpty ? 'Studio' : value;
  }
}
