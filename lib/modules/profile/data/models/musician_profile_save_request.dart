class MusicianProfileSaveRequest {
  final String? stageName;
  final String? description;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? soundcloudUrl;
  final String? spotifyEmbedUrl;
  final String? spotifyArtistId;
  final List<String>? instrumentIds;
  final String? profilePicture;

  const MusicianProfileSaveRequest({
    this.stageName,
    this.description,
    this.instagramUrl,
    this.youtubeUrl,
    this.soundcloudUrl,
    this.spotifyEmbedUrl,
    this.spotifyArtistId,
    this.instrumentIds,
    this.profilePicture,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> payload = {};

    void addIfNotEmpty(String key, String? value) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        payload[key] = trimmed;
      }
    }

    addIfNotEmpty('stageName', stageName);
    addIfNotEmpty('description', description);
    addIfNotEmpty('instagramUrl', instagramUrl);
    addIfNotEmpty('youtubeUrl', youtubeUrl);
    addIfNotEmpty('soundcloudUrl', soundcloudUrl);
    addIfNotEmpty('spotifyEmbedUrl', spotifyEmbedUrl);
    addIfNotEmpty('spotifyArtistId', spotifyArtistId);
    addIfNotEmpty('profilePicture', profilePicture);

    if (instrumentIds != null) {
      payload['instrumentIds'] = instrumentIds;
    }

    return payload;
  }
}
