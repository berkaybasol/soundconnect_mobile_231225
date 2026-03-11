class SpotifyEndpoints {
  static const String base = '/api/v1/spotify';

  static const String searchTracks = '$base/search/tracks';
  static const String tracksByIds = '$base/tracks/by-ids';
  static String trackById(String trackId) => '$base/tracks/$trackId';
}
