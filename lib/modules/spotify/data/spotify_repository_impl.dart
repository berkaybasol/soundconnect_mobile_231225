import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/spotify_repository.dart';
import '../domain/entities/spotify_track_preview.dart';
import 'models/spotify_track_preview_model.dart';
import 'spotify_endpoints.dart';

class SpotifyRepositoryImpl implements SpotifyRepository {
  final ApiClient _apiClient;

  SpotifyRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<SpotifyTrackPreview>>> searchTracks(
    String query, {
    int limit = 5,
  }) async {
    try {
      final response = await _apiClient.get<List<SpotifyTrackPreview>>(
        SpotifyEndpoints.searchTracks,
        query: {
          'q': query,
          'limit': limit,
        },
        decoder: (json) {
          final data = json as Map<String, dynamic>? ?? {};
          final list = data['tracks'] as List<dynamic>? ?? [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(SpotifyTrackPreviewModel.fromJson)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'spotify_search_unknown',
        message: 'Spotify arama sonucu alinmadi',
      ));
    }
  }

  @override
  Future<Result<List<SpotifyTrackPreview>>> getTracksByIds(
    List<String> ids,
  ) async {
    try {
      final response = await _apiClient.post<List<SpotifyTrackPreview>>(
        SpotifyEndpoints.tracksByIds,
        body: {'ids': ids},
        decoder: (json) {
          final list = json as List<dynamic>? ?? [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(SpotifyTrackPreviewModel.fromJson)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'spotify_tracks_by_ids_unknown',
        message: 'Spotify track listesi alinmadi',
      ));
    }
  }
}
