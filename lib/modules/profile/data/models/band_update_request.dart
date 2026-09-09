class BandUpdateRequest {
  final String? name;
  final String? description;
  final String? profilePicture;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? soundCloudUrl;
  final String? spotifyEmbedUrl;
  final String? spotifyArtistId;
  final List<String>? spotifyTrackIds;

  const BandUpdateRequest({
    this.name,
    this.description,
    this.profilePicture,
    this.instagramUrl,
    this.youtubeUrl,
    this.soundCloudUrl,
    this.spotifyEmbedUrl,
    this.spotifyArtistId,
    this.spotifyTrackIds,
  });

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{};

    void addIfNotEmpty(String key, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        payload[key] = trimmed;
      }
    }

    addIfNotEmpty('name', name);
    if (description != null) payload['description'] = description!.trim();
    addIfNotEmpty('profilePicture', profilePicture);
    if (instagramUrl != null) payload['instagramUrl'] = instagramUrl!.trim();
    if (youtubeUrl != null) payload['youtubeUrl'] = youtubeUrl!.trim();
    if (soundCloudUrl != null) payload['soundCloudUrl'] = soundCloudUrl!.trim();
    if (spotifyEmbedUrl != null) {
      payload['spotifyEmbedUrl'] = spotifyEmbedUrl!.trim();
    }
    if (spotifyArtistId != null) {
      payload['spotifyArtistId'] = spotifyArtistId!.trim();
    }
    if (spotifyTrackIds != null) {
      payload['spotifyTrackIds'] = spotifyTrackIds;
    }
    return payload;
  }
}
