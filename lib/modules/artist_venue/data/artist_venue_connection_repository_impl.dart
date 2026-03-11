import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/artist_venue_connection_repository.dart';
import 'artist_venue_connection_endpoints.dart';
import 'models/artist_venue_connection_response.dart';

class ArtistVenueConnectionRepositoryImpl
    implements ArtistVenueConnectionRepository {
  final ApiClient _apiClient;

  ArtistVenueConnectionRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<String>>> getAcceptedVenues(
    String musicianProfileId,
  ) async {
    try {
      final response = await _apiClient.get<List<String>>(
        ArtistVenueConnectionEndpoints.byMusician(
          musicianProfileId,
          status: 'ACCEPTED',
        ),
        decoder: (json) {
          final list = (json as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(ArtistVenueConnectionResponse.fromJson)
              .map((item) => item.venueName)
              .whereType<String>()
              .where((name) => name.isNotEmpty)
              .toList();
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'artist_venue_connections_unknown',
        message: 'Active venues could not be loaded',
      ));
    }
  }
}
