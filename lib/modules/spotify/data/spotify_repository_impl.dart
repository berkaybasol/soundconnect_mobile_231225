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
        query: {'q': query, 'limit': limit},
        decoder: (json) {
          List<dynamic> extractTrackList(Object? node) {
            if (node is List<dynamic>) return node;
            if (node is! Map<String, dynamic>) return const [];

            final tracks = node['tracks'];
            if (tracks is List<dynamic>) return tracks;

            if (tracks is Map<String, dynamic>) {
              final nestedTracks = tracks['tracks'];
              if (nestedTracks is List<dynamic>) return nestedTracks;
              final items = tracks['items'];
              if (items is List<dynamic>) return items;
            }

            final items = node['items'];
            if (items is List<dynamic>) return items;

            return const [];
          }

          // ApiClient already unwraps BaseResponse.data and passes only raw data.
          final list = extractTrackList(json);
          return list
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(SpotifyTrackPreviewModel.fromJson)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'spotify_search_unknown',
          message: 'Spotify arama sonucu alinmadi',
        ),
      );
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
          // ApiClient already unwraps BaseResponse.data and passes only raw data.
          final list = json is List<dynamic> ? json : const <dynamic>[];
          return list
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .map(SpotifyTrackPreviewModel.fromJson)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'spotify_tracks_by_ids_unknown',
          message: 'Spotify track listesi alinmadi',
        ),
      );
    }
  }
}
