import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/event_performer_identity.dart';
import '../domain/entities/venue_event_detail.dart';
import '../domain/entities/venue_event_item.dart';
import '../domain/venue_event_repository.dart';

class VenueEventRepositoryImpl implements VenueEventRepository {
  final ApiClient _apiClient;
  final String? Function()? sessionKeyProvider;

  VenueEventRepositoryImpl(this._apiClient, {this.sessionKeyProvider});
  String? get _session => sessionKeyProvider?.call()?.trim();
  bool _sessionValid(String? expected) =>
      sessionKeyProvider == null ||
      (expected?.isNotEmpty == true && expected == _session);
  static const _sessionError = AppError(
    code: 'venue_event_session_changed',
    message: 'Oturum değişti. Etkinlik yönetimini yeniden aç.',
  );

  Future<void> _mutate(
    ApiHttpMethod method,
    String path, {
    Object? body,
    String? session,
  }) async {
    if (sessionKeyProvider == null) {
      if (method == ApiHttpMethod.post) {
        await _apiClient.post<Object?>(path, body: body, decoder: (_) => null);
      } else {
        await _apiClient.delete<Object?>(path, decoder: (_) => null);
      }
    } else {
      await _apiClient.request<Object?>(
        method,
        path,
        body: body,
        decoder: (_) => null,
        requestContext: ApiRequestContext(expectedSessionKey: session),
      );
    }
  }

  @override
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String venueId) async {
    final session = _session;
    if (!_sessionValid(session)) return const Result.failure(_sessionError);
    try {
      final response = await _apiClient.get<List<VenueOwnerEventItem>>(
        '/api/v1/venue-owner/events/venue/$venueId',
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .where(_isVenueEvent)
              .map(VenueOwnerEventItem.fromJson)
              .toList();
        },
      );
      if (!_sessionValid(session)) return const Result.failure(_sessionError);
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_events_list_unknown',
          message: 'Etkinlikler alinamadi',
        ),
      );
    }
  }

  @override
  Future<Result<List<VenueOwnerEventItem>>> listPublicByVenue(
    String venueId,
  ) async {
    try {
      final response = await _apiClient.get<List<VenueOwnerEventItem>>(
        '/api/v1/events/venue/$venueId',
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .where(_isVenueEvent)
              .map(VenueOwnerEventItem.fromJson)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_events_public_list_unknown',
          message: 'Etkinlikler alinamadi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> create({
    required String venueId,
    required VenueEventDraft draft,
  }) async {
    final session = _session;
    if (!_sessionValid(session)) return const Result.failure(_sessionError);
    final normalizedVenueId = venueId.trim();
    final musicianProfileId = _nonBlank(draft.musicianProfileId);
    final bandId = _nonBlank(draft.bandId);
    final manualPerformerName = _nonBlank(draft.manualPerformerName);
    final rawPerformerFields = <String?>[
      draft.musicianProfileId,
      draft.bandId,
      draft.manualPerformerName,
    ];
    final hasBlankPerformerField = rawPerformerFields.any(
      (value) => value != null && value.trim().isEmpty,
    );
    final performerFieldCount = <String?>[
      musicianProfileId,
      bandId,
      manualPerformerName,
    ].where((value) => value != null).length;
    if (normalizedVenueId.isEmpty ||
        hasBlankPerformerField ||
        performerFieldCount > 1) {
      return const Result.failure(
        AppError(
          code: 'venue_event_invalid_performer',
          message: 'Etkinlik sanatçısı veya grubu geçersiz.',
        ),
      );
    }
    try {
      await _mutate(
        ApiHttpMethod.post,
        '/api/v1/venue-owner/events',
        session: session,
        body: {
          'title': draft.title,
          'description': draft.description.isEmpty ? null : draft.description,
          'eventDate': formatVenueApiDate(draft.eventDate),
          'startTime': formatVenueApiTime(draft.startTime),
          'endTime': draft.endTime == null
              ? null
              : formatVenueApiTime(draft.endTime!),
          'posterImage': draft.posterImage,
          'venueId': normalizedVenueId,
          'musicianProfileId': musicianProfileId,
          'bandId': bandId,
          'manualPerformerName': manualPerformerName,
        },
      );
      if (!_sessionValid(session)) return const Result.failure(_sessionError);
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_event_create_unknown',
          message: 'Etkinlik eklenemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(String eventId) async {
    final session = _session;
    if (!_sessionValid(session)) return const Result.failure(_sessionError);
    try {
      await _mutate(
        ApiHttpMethod.delete,
        '/api/v1/venue-owner/events/$eventId',
        session: session,
      );
      if (!_sessionValid(session)) return const Result.failure(_sessionError);
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_event_delete_unknown',
          message: 'Etkinlik silinemedi',
        ),
      );
    }
  }

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async {
    final normalizedEventId = eventId.trim();
    if (normalizedEventId.isEmpty) {
      return const Result.failure(
        AppError(
          code: 'venue_event_detail_invalid_id',
          message: 'Etkinlik detayı bulunamadı.',
        ),
      );
    }
    try {
      final response = await _apiClient.get<VenueEventDetail>(
        '/api/v1/events/${Uri.encodeComponent(normalizedEventId)}',
        decoder: (json) {
          if (json is! Map<Object?, Object?>) {
            throw const FormatException('Expected an event detail object.');
          }
          final map = json.cast<String, dynamic>();
          if (!_isVenueEvent(map)) {
            throw const FormatException(
              'Only venue-created events are supported.',
            );
          }
          final responseId = _nonBlank(map['id']);
          if (responseId != normalizedEventId) {
            throw const FormatException('Event detail identity disagrees.');
          }
          final performerIdentity = EventPerformerIdentity.fromWire(
            performerType: map['performerType'],
            musicianProfileId: map['musicianProfileId'],
            bandId: map['bandId'],
          );
          return VenueEventDetail(
            id: normalizedEventId,
            shareUrl: map['shareUrl']?.toString(),
            posterImage: map['posterImage']?.toString(),
            performerName: map['performerName']?.toString(),
            musicianProfileId: performerIdentity.musicianProfileId,
            bandId: performerIdentity.bandId,
            performerType: performerIdentity.performerType,
            title: map['title']?.toString(),
            description: map['description']?.toString(),
            eventDate: DateTime.tryParse(map['eventDate']?.toString() ?? ''),
            startTime: map['startTime']?.toString(),
            endTime: map['endTime']?.toString(),
            venueId: map['venueId']?.toString(),
            venueName: map['venueName']?.toString(),
            venueCity: map['venueCity']?.toString(),
            venueDistrict: map['venueDistrict']?.toString(),
            venueNeighborhood: map['venueNeighborhood']?.toString(),
          );
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'venue_event_detail_malformed_response',
          message: 'Etkinlik detayı geçersiz bir yanıt döndürdü.',
        ),
      );
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_event_detail_unknown',
          message: 'Etkinlik detayi alinamadi',
        ),
      );
    }
  }

  // Older venue-only responses omit origin; the compatibility schema sends VENUE.
  static bool _isVenueEvent(Map<String, dynamic> json) =>
      !json.containsKey('eventOrigin') || json['eventOrigin'] == 'VENUE';

  static String? _nonBlank(Object? value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
