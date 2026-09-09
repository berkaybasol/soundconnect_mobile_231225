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

    if (bio != null) payload['bio'] = bio!.trim();
    addIfNotEmpty('profilePicture', profilePicture);
    if (instagramUrl != null) payload['instagramUrl'] = instagramUrl!.trim();
    if (youtubeUrl != null) payload['youtubeUrl'] = youtubeUrl!.trim();
    if (websiteUrl != null) payload['websiteUrl'] = websiteUrl!.trim();

    return payload;
  }
}
