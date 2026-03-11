import '../../../core/error/result.dart';
import 'entities/spotify_track_preview.dart';

abstract class SpotifyRepository {
  Future<Result<List<SpotifyTrackPreview>>> searchTracks(
    String query, {
    int limit = 5,
  });
  Future<Result<List<SpotifyTrackPreview>>> getTracksByIds(List<String> ids);
}
