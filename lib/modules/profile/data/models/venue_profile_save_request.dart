class VenueProfileSaveRequest {
  final String? bio;
  final String? profilePicture;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? websiteUrl;

  const VenueProfileSaveRequest({
    this.bio,
    this.profilePicture,
    this.instagramUrl,
    this.youtubeUrl,
    this.websiteUrl,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> payload = {};

    void addIfNotEmpty(String key, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        payload[key] = trimmed;
      }
    }

    addIfNotEmpty('bio', bio);
    addIfNotEmpty('profilePicture', profilePicture);
    addIfNotEmpty('instagramUrl', instagramUrl);
    addIfNotEmpty('youtubeUrl', youtubeUrl);
    addIfNotEmpty('websiteUrl', websiteUrl);

    return payload;
  }
}
