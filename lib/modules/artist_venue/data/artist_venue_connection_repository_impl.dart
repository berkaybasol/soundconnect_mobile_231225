import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../profile/domain/entities/artist_venue_application.dart';
import '../../profile/domain/entities/profile_venue_models.dart';
import '../domain/artist_venue_connection_repository.dart';
import '../domain/artist_venue_application_page.dart';
import 'artist_venue_connection_endpoints.dart';
import 'models/artist_venue_connection_response.dart';

class ArtistVenueConnectionRepositoryImpl
    implements ArtistVenueConnectionRepository {
  final ApiClient _apiClient;

  ArtistVenueConnectionRepositoryImpl(this._apiClient);

  @override
  Future<Result<ArtistVenueApplicationPage>> listApplicationPage({
    required ArtistVenueApplicationTarget target,
    required String targetId,
    required bool incoming,
    bool connectionsOnly = false,
    int page = 0,
    int size = 20,
    String? expectedSessionKey,
  }) async {
    if (targetId.trim().isEmpty ||
        page < 0 ||
        page > 10000 ||
        size < 1 ||
        size > 100) {
      return const Result.failure(
        AppError(code: 'invalid_page', message: 'İstek sayfası geçersiz.'),
      );
    }
    try {
      final result = await _apiClient.request<ArtistVenueApplicationPage>(
        ApiHttpMethod.get,
        '${ArtistVenueConnectionEndpoints.base}/${target.name}/${Uri.encodeComponent(targetId)}/page',
        query: {
          if (connectionsOnly) 'status': 'ACCEPTED' else 'incoming': incoming,
          'page': page,
          'size': size,
        },
        requestContext: expectedSessionKey == null
            ? null
            : ApiRequestContext(expectedSessionKey: expectedSessionKey),
        decoder: ArtistVenueApplicationPage.fromJson,
      );
      if (result.page != page ||
          result.size != size ||
          result.items.any((item) {
            final matches = switch (target) {
              ArtistVenueApplicationTarget.musician =>
                item.musicianProfileId == targetId && item.bandId.isEmpty,
              ArtistVenueApplicationTarget.band =>
                item.bandId == targetId && item.musicianProfileId.isEmpty,
              ArtistVenueApplicationTarget.venue => item.venueId == targetId,
            };
            final recipientSide = target == ArtistVenueApplicationTarget.venue
                ? item.requestByType != 'VENUE'
                : item.requestByType == 'VENUE';
            return !matches ||
                (connectionsOnly
                    ? item.status != 'ACCEPTED'
                    : recipientSide != incoming);
          })) {
        throw const FormatException('Application scope mismatch');
      }
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'artist_venue_page_failed',
          message: 'İstekler getirilemedi. Yeniden dene.',
        ),
      );
    }
  }

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
      return Result.failure(
        const AppError(
          code: 'artist_venue_connections_unknown',
          message: 'Active venues could not be loaded',
        ),
      );
    }
  }

  @override
  Future<Result<List<VenueConnection>>> getVenueConnectionsByStatus(
    String musicianProfileId, {
    required String status,
  }) async {
    try {
      final response = await _apiClient.get<List<VenueConnection>>(
        ArtistVenueConnectionEndpoints.byMusician(
          musicianProfileId,
          status: status,
        ),
        decoder: (json) {
          final list = (json as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(ArtistVenueConnectionResponse.fromJson)
              .map(
                (item) => VenueConnection(
                  requestId: item.id,
                  venueId: item.venueId,
                  venueName: item.venueName ?? '',
                  profileImageUrl: item.venueProfilePictureUrl,
                ),
              )
              .where(
                (item) => item.requestId.isNotEmpty && item.venueId.isNotEmpty,
              )
              .toList();
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'artist_venue_status_unknown',
          message: 'Venue baglanti listesi alinmadi',
        ),
      );
    }
  }

  @override
  Future<Result<List<MusicianConnection>>> getMusicianConnectionsByStatus(
    String venueId, {
    required String status,
  }) async {
    try {
      final response = await _apiClient.get<List<MusicianConnection>>(
        ArtistVenueConnectionEndpoints.byVenue(venueId, status: status),
        decoder: (json) {
          final list = (json as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(ArtistVenueConnectionResponse.fromJson)
              .map(
                (item) => MusicianConnection(
                  requestId: item.id,
                  musicianProfileId: item.musicianProfileId,
                  musicianName: item.musicianStageName ?? 'Sanatci',
                ),
              )
              .where(
                (item) =>
                    item.requestId.isNotEmpty &&
                    item.musicianProfileId.isNotEmpty,
              )
              .toList();
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_artist_status_unknown',
          message: 'Muzisyen baglanti listesi alinamadi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> createArtistRequest({
    required String musicianProfileId,
    required String venueId,
    required String message,
    String? expectedSessionKey,
  }) async {
    return _createRequest(
      requestByType: 'ARTIST',
      expectedSessionKey: expectedSessionKey,
      body: {
        'musicianProfileId': musicianProfileId,
        'venueId': venueId,
        'message': message,
      },
    );
  }

  @override
  Future<Result<void>> createBandRequest({
    required String bandId,
    required String venueId,
    required String message,
    String? expectedSessionKey,
  }) async {
    return _createRequest(
      requestByType: 'BAND',
      expectedSessionKey: expectedSessionKey,
      body: {'bandId': bandId, 'venueId': venueId, 'message': message},
    );
  }

  @override
  Future<Result<void>> createVenueRequest({
    required String musicianProfileId,
    required String venueId,
    required String message,
    String? expectedSessionKey,
  }) async {
    return _createRequest(
      requestByType: 'VENUE',
      expectedSessionKey: expectedSessionKey,
      body: {
        'musicianProfileId': musicianProfileId,
        'venueId': venueId,
        'message': message,
      },
    );
  }

  @override
  Future<Result<void>> createVenueBandRequest({
    required String bandId,
    required String venueId,
    required String message,
    String? expectedSessionKey,
  }) async {
    return _createRequest(
      requestByType: 'VENUE',
      expectedSessionKey: expectedSessionKey,
      body: {'bandId': bandId, 'venueId': venueId, 'message': message},
    );
  }

  Future<Result<void>> _createRequest({
    required String requestByType,
    required Map<String, dynamic> body,
    String? expectedSessionKey,
  }) async {
    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.post,
        ArtistVenueConnectionEndpoints.request(requestByType),
        body: body,
        decoder: (_) => null,
        requestContext: expectedSessionKey == null
            ? null
            : ApiRequestContext(expectedSessionKey: expectedSessionKey),
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'artist_venue_request_unknown',
          message: 'Baglanti istegi gonderilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<List<VenueConnection>>> getVenueConnectionsByBandStatus(
    String bandId, {
    required String status,
  }) async {
    try {
      final response = await _apiClient.get<List<VenueConnection>>(
        ArtistVenueConnectionEndpoints.byBand(bandId, status: status),
        decoder: (json) {
          final list = (json as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(ArtistVenueConnectionResponse.fromJson)
              .map(
                (item) => VenueConnection(
                  requestId: item.id,
                  venueId: item.venueId,
                  venueName: item.venueName ?? '',
                  profileImageUrl: item.venueProfilePictureUrl,
                ),
              )
              .where(
                (item) => item.requestId.isNotEmpty && item.venueId.isNotEmpty,
              )
              .toList();
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_venue_status_unknown',
          message: 'Band mekan baglanti listesi alinamadi',
        ),
      );
    }
  }

  @override
  Future<Result<List<ArtistVenueApplication>>> listVenueApplications(
    String venueId,
  ) async {
    try {
      final response = await _apiClient.get<List<ArtistVenueApplication>>(
        ArtistVenueConnectionEndpoints.byVenue(venueId),
        decoder: (json) {
          final list =
              (json as List<dynamic>? ?? const [])
                  .whereType<Map<String, dynamic>>()
                  .map(ArtistVenueConnectionResponse.fromJson)
                  .map(
                    (item) => ArtistVenueApplication(
                      id: item.id,
                      musicianProfileId: item.musicianProfileId,
                      bandId: item.bandId,
                      venueId: item.venueId,
                      musicianStageName: item.musicianStageName ?? '',
                      bandName: item.bandName ?? '',
                      bandProfilePictureUrl: item.bandProfilePictureUrl,
                      venueProfilePictureUrl: item.venueProfilePictureUrl,
                      venueName: item.venueName ?? 'Mekan',
                      message: item.message,
                      status: item.status ?? 'PENDING',
                      requestByType: item.requestByType ?? 'ARTIST',
                      createdAt: item.createdAt ?? '',
                    ),
                  )
                  .where((item) => item.id.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'artist_venue_applications_unknown',
          message: 'Basvurular getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<List<ArtistVenueApplication>>> listMusicianVenueApplications(
    String musicianProfileId,
  ) async {
    try {
      final response = await _apiClient.get<List<ArtistVenueApplication>>(
        ArtistVenueConnectionEndpoints.byMusician(musicianProfileId),
        decoder: (json) {
          final list =
              (json as List<dynamic>? ?? const [])
                  .whereType<Map<String, dynamic>>()
                  .map(ArtistVenueConnectionResponse.fromJson)
                  .map(
                    (item) => ArtistVenueApplication(
                      id: item.id,
                      musicianProfileId: item.musicianProfileId,
                      bandId: item.bandId,
                      venueId: item.venueId,
                      musicianStageName: item.musicianStageName ?? '',
                      bandName: item.bandName ?? '',
                      bandProfilePictureUrl: item.bandProfilePictureUrl,
                      venueProfilePictureUrl: item.venueProfilePictureUrl,
                      venueName: item.venueName ?? 'Mekan',
                      message: item.message,
                      status: item.status ?? 'PENDING',
                      requestByType: item.requestByType ?? 'VENUE',
                      createdAt: item.createdAt ?? '',
                    ),
                  )
                  .where((item) => item.id.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'musician_venue_applications_unknown',
          message: 'Mekan basvurulari getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<List<ArtistVenueApplication>>> listBandVenueApplications(
    String bandId,
  ) async {
    try {
      final response = await _apiClient.get<List<ArtistVenueApplication>>(
        ArtistVenueConnectionEndpoints.byBand(bandId),
        decoder: (json) {
          final list =
              (json as List<dynamic>? ?? const [])
                  .whereType<Map<String, dynamic>>()
                  .map(ArtistVenueConnectionResponse.fromJson)
                  .map(
                    (item) => ArtistVenueApplication(
                      id: item.id,
                      musicianProfileId: item.musicianProfileId,
                      bandId: item.bandId,
                      venueId: item.venueId,
                      musicianStageName: item.musicianStageName ?? '',
                      bandName: item.bandName ?? '',
                      bandProfilePictureUrl: item.bandProfilePictureUrl,
                      venueProfilePictureUrl: item.venueProfilePictureUrl,
                      venueName: item.venueName ?? 'Mekan',
                      message: item.message,
                      status: item.status ?? 'PENDING',
                      requestByType: item.requestByType ?? 'BAND',
                      createdAt: item.createdAt ?? '',
                    ),
                  )
                  .where((item) => item.id.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_venue_applications_unknown',
          message: 'Band mekan basvurulari getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> acceptRequest(
    String requestId, {
    String? expectedSessionKey,
  }) {
    return _postAction(
      '${ArtistVenueConnectionEndpoints.base}/$requestId/accept',
      expectedSessionKey: expectedSessionKey,
    );
  }

  @override
  Future<Result<void>> rejectRequest(
    String requestId, {
    String? expectedSessionKey,
  }) {
    return _postAction(
      '${ArtistVenueConnectionEndpoints.base}/$requestId/reject',
      expectedSessionKey: expectedSessionKey,
    );
  }

  @override
  Future<Result<void>> cancelRequest(
    String requestId, {
    String? expectedSessionKey,
  }) {
    return _postAction(
      '${ArtistVenueConnectionEndpoints.base}/$requestId/cancel',
      expectedSessionKey: expectedSessionKey,
    );
  }

  @override
  Future<Result<void>> disconnect(
    String requestId, {
    String? expectedSessionKey,
  }) async {
    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.delete,
        '${ArtistVenueConnectionEndpoints.base}/$requestId/disconnect',
        requestContext: expectedSessionKey == null
            ? null
            : ApiRequestContext(expectedSessionKey: expectedSessionKey),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'artist_venue_disconnect_unknown',
          message: 'Baglanti kaldirilamadi',
        ),
      );
    }
  }

  Future<Result<void>> _postAction(
    String path, {
    String? expectedSessionKey,
  }) async {
    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.post,
        path,
        decoder: (_) => null,
        requestContext: expectedSessionKey == null
            ? null
            : ApiRequestContext(expectedSessionKey: expectedSessionKey),
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'artist_venue_action_unknown',
          message: 'Islem tamamlanamadi',
        ),
      );
    }
  }
}
