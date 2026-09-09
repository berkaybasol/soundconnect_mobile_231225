class MusicianProfileSaveRequest {
  final String? stageName;
  final String? description;
  final String? instagramUrl;
  final String? youtubeUrl;
  final String? soundcloudUrl;
  final String? spotifyEmbedUrl;
  final String? spotifyArtistId;
  final List<String>? spotifyTrackIds;
  final List<Map<String, dynamic>>? spotifyTracks;
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
    this.spotifyTrackIds,
    this.spotifyTracks,
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
    // Null means unchanged; an explicit empty value clears an optional field.
    if (description != null) payload['description'] = description!.trim();
    if (instagramUrl != null) payload['instagramUrl'] = instagramUrl!.trim();
    if (youtubeUrl != null) payload['youtubeUrl'] = youtubeUrl!.trim();
    if (soundcloudUrl != null) payload['soundcloudUrl'] = soundcloudUrl!.trim();
    if (spotifyEmbedUrl != null) {
      payload['spotifyEmbedUrl'] = spotifyEmbedUrl!.trim();
    }
    if (spotifyArtistId != null) {
      payload['spotifyArtistId'] = spotifyArtistId!.trim();
    }
    addIfNotEmpty('profilePicture', profilePicture);

    if (spotifyTrackIds != null) {
      payload['spotifyTrackIds'] = spotifyTrackIds;
    }
    if (spotifyTracks != null) {
      payload['spotifyTracks'] = spotifyTracks;
    }

    if (instrumentIds != null) {
      payload['instrumentIds'] = instrumentIds;
    }

    return payload;
  }
}
