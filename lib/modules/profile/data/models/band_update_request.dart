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
    addIfNotEmpty('description', description);
    addIfNotEmpty('profilePicture', profilePicture);
    addIfNotEmpty('instagramUrl', instagramUrl);
    addIfNotEmpty('youtubeUrl', youtubeUrl);
    addIfNotEmpty('soundCloudUrl', soundCloudUrl);
    addIfNotEmpty('spotifyEmbedUrl', spotifyEmbedUrl);
    addIfNotEmpty('spotifyArtistId', spotifyArtistId);
    if (spotifyTrackIds != null) {
      payload['spotifyTrackIds'] = spotifyTrackIds;
    }
    return payload;
  }
}
