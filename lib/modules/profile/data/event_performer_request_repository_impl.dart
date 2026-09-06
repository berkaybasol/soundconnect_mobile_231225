import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/event_performer_request.dart';
import '../domain/event_performer_request_repository.dart';
import 'event_performer_request_endpoints.dart';
import 'models/event_performer_request_model.dart';

class EventPerformerRequestRepositoryImpl
    implements EventPerformerRequestRepository {
  final ApiClient _apiClient;

  const EventPerformerRequestRepositoryImpl(
    this._apiClient, {
    this.onDecision,
    this.sessionKeyProvider,
  });

  final void Function()? onDecision;
  final String? Function()? sessionKeyProvider;
  String? get _session => sessionKeyProvider?.call()?.trim();
  bool _sessionValid(String? expected) =>
      sessionKeyProvider == null ||
      (expected?.isNotEmpty == true && expected == _session);
  static const _sessionError = AppError(
    code: 'event_performer_session_changed',
    message: 'Oturum değişti. Etkinlik davetlerini yeniden aç.',
  );

  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async {
    final session = _session;
    if (!_sessionValid(session)) return const Result.failure(_sessionError);
    if (page < 0 || page > 100 || size < 1 || size > 50) {
      return const Result.failure(
        AppError(
          code: 'event_performer_requests_invalid_page',
          message: 'Etkinlik onayı sayfası geçersiz.',
        ),
      );
    }
    final normalizedTargetId = targetId?.trim() ?? '';
    if ((targetType == null) != (targetId == null) ||
        (targetId != null && normalizedTargetId.isEmpty)) {
      return const Result.failure(
        AppError(
          code: 'event_performer_requests_invalid_target',
          message: 'Etkinlik onayı profili geçersiz.',
        ),
      );
    }
    try {
      final query = <String, dynamic>{
        'status': status.name.toUpperCase(),
        'page': page,
        'size': size,
      };
      if (targetType != null) {
        query['targetType'] = targetType.wireValue;
        query['targetId'] = normalizedTargetId;
      }
      EventPerformerRequestPage decode(Object? json) => _decodePage(
        json,
        requestedPage: page,
        requestedSize: size,
        requestedStatus: status,
        requestedTargetType: targetType,
        requestedTargetId: normalizedTargetId,
      );
      final response = sessionKeyProvider == null
          ? await _apiClient.get<EventPerformerRequestPage>(
              EventPerformerRequestEndpoints.mine,
              query: query,
              decoder: decode,
            )
          : await _apiClient.request<EventPerformerRequestPage>(
              ApiHttpMethod.get,
              EventPerformerRequestEndpoints.mine,
              query: query,
              decoder: decode,
              requestContext: ApiRequestContext(expectedSessionKey: session),
            );
      if (!_sessionValid(session)) return const Result.failure(_sessionError);
      return Result.success(response);
    } on ApiException catch (error) {
      return Result.failure(
        _sessionValid(session) ? error.error : _sessionError,
      );
    } on FormatException {
      return Result.failure(
        !_sessionValid(session)
            ? _sessionError
            : const AppError(
                code: 'event_performer_requests_malformed_response',
                message: 'Etkinlik davetleri geçersiz bir yanıt döndürdü.',
              ),
      );
    } catch (_) {
      return Result.failure(
        !_sessionValid(session)
            ? _sessionError
            : const AppError(
                code: 'event_performer_requests_unknown',
                message: 'Etkinlik davetleri alınamadı.',
              ),
      );
    }
  }

  static EventPerformerRequestPage _decodePage(
    Object? json, {
    required int requestedPage,
    required int requestedSize,
    required EventPerformerRequestStatus requestedStatus,
    required EventPerformerTargetType? requestedTargetType,
    required String requestedTargetId,
  }) {
    if (json is List<dynamic>) {
      if (requestedPage != 0) {
        throw const FormatException(
          'Legacy request lists are valid only for the first page.',
        );
      }
      final items = _decodeItems(
        json,
        requestedStatus: requestedStatus,
        requestedTargetType: requestedTargetType,
        requestedTargetId: requestedTargetId,
      );
      return EventPerformerRequestPage(
        items: items,
        page: requestedPage,
        size: items.length,
        totalElements: items.length,
        totalPages: items.isEmpty ? 0 : 1,
        hasNext: false,
      );
    }
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Expected a page object or legacy list.');
    }

    final rawContent = json['content'];
    if (rawContent is! List<dynamic>) {
      throw const FormatException('Page content is missing.');
    }
    final responsePage = _requiredInt(json['page'] ?? json['number'], 'page');
    final legacyNumber = json['number'];
    if (legacyNumber != null &&
        _requiredInt(legacyNumber, 'number') != responsePage) {
      throw const FormatException('Page number aliases disagree.');
    }
    final responseSize = _requiredInt(json['size'], 'size');
    final totalElements = _requiredInt(json['totalElements'], 'totalElements');
    final totalPages = _requiredInt(json['totalPages'], 'totalPages');
    final first = json['first'];
    final last = json['last'];
    if (first is! bool || last is! bool) {
      throw const FormatException('Page boundary flags are missing.');
    }
    if (responsePage < 0 ||
        responsePage != requestedPage ||
        responseSize != requestedSize ||
        totalElements < 0 ||
        totalPages < 0 ||
        (responsePage == 0) != first) {
      throw const FormatException('Page metadata is invalid.');
    }
    final expectedTotalPages = totalElements == 0
        ? 0
        : (totalElements + responseSize - 1) ~/ responseSize;
    final outOfRange = responsePage > 0 && responsePage >= totalPages;
    if (totalPages != expectedTotalPages ||
        (outOfRange && (rawContent.isNotEmpty || !last)) ||
        rawContent.length > responseSize ||
        rawContent.length > totalElements) {
      throw const FormatException('Page totals are inconsistent.');
    }
    final expectedLast = totalPages == 0 || responsePage + 1 >= totalPages;
    if (last != expectedLast) {
      throw const FormatException('Page boundary metadata is inconsistent.');
    }

    return EventPerformerRequestPage(
      items: _decodeItems(
        rawContent,
        requestedStatus: requestedStatus,
        requestedTargetType: requestedTargetType,
        requestedTargetId: requestedTargetId,
      ),
      page: responsePage,
      size: responseSize,
      totalElements: totalElements,
      totalPages: totalPages,
      hasNext: !last,
    );
  }

  static List<EventPerformerRequest> _decodeItems(
    List<dynamic> rawItems, {
    required EventPerformerRequestStatus requestedStatus,
    required EventPerformerTargetType? requestedTargetType,
    required String requestedTargetId,
  }) {
    final items = <EventPerformerRequest>[];
    final requestIds = <String>{};
    for (final rawItem in rawItems) {
      if (rawItem is! Map<String, dynamic>) {
        throw const FormatException('Page contains an invalid request.');
      }
      final item = EventPerformerRequestModel.fromJson(rawItem);
      if (item.requestId.isEmpty ||
          item.eventId.isEmpty ||
          item.targetId.isEmpty ||
          item.status != requestedStatus ||
          !item.targets(type: requestedTargetType, id: requestedTargetId) ||
          !requestIds.add(item.requestId)) {
        throw const FormatException('Request identity is missing.');
      }
      items.add(item);
    }
    return List.unmodifiable(items);
  }

  static int _requiredInt(Object? raw, String field) {
    if (raw is int) return raw;
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed == null) throw FormatException('$field is missing.');
    return parsed;
  }

  @override
  Future<Result<void>> accept(String requestId, {bool showOnProfile = false}) =>
      _postDecision(
        requestId,
        EventPerformerRequestEndpoints.accept,
        showOnProfile: showOnProfile,
      );

  @override
  Future<Result<void>> reject(String requestId) =>
      _postDecision(requestId, EventPerformerRequestEndpoints.reject);

  @override
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  }) => _postDecision(
    requestId,
    EventPerformerRequestEndpoints.reconsider,
    showOnProfile: showOnProfile,
    confirmAccepted: true,
  );

  Future<Result<void>> _postDecision(
    String requestId,
    String Function(String requestId) pathBuilder, {
    bool? showOnProfile,
    bool confirmAccepted = false,
  }) async {
    final session = _session;
    if (!_sessionValid(session)) return const Result.failure(_sessionError);
    final normalizedId = requestId.trim();
    if (normalizedId.isEmpty) {
      return const Result.failure(
        AppError(
          code: 'event_performer_request_id_missing',
          message: 'Etkinlik onayı bulunamadı.',
        ),
      );
    }
    try {
      Object? decode(Object? raw) {
        if (!confirmAccepted) return null;
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Missing reconsideration confirmation.');
        }
        final confirmed = EventPerformerRequestModel.fromJson(raw);
        if (confirmed.requestId != normalizedId ||
            !confirmed.hasValidTargetIdentity ||
            confirmed.status != EventPerformerRequestStatus.accepted ||
            confirmed.profileCalendarApproved == null) {
          throw const FormatException('Reconsideration was not confirmed.');
        }
        // Publication may have changed independently after an earlier,
        // successfully committed reconsideration. Do not infer its current
        // value from this request or replay another publication mutation.
        return null;
      }

      if (sessionKeyProvider == null) {
        await _apiClient.post<Object?>(
          pathBuilder(normalizedId),
          body: showOnProfile == null ? null : {'showOnProfile': showOnProfile},
          decoder: decode,
        );
      } else {
        await _apiClient.request<Object?>(
          ApiHttpMethod.post,
          pathBuilder(normalizedId),
          body: showOnProfile == null ? null : {'showOnProfile': showOnProfile},
          decoder: decode,
          requestContext: ApiRequestContext(expectedSessionKey: session),
        );
      }
      if (!_sessionValid(session)) return const Result.failure(_sessionError);
      try {
        onDecision?.call();
      } catch (_) {
        // Observers cannot turn an already committed decision into a failure.
      }
      return const Result.success(null);
    } on ApiException catch (error) {
      return Result.failure(
        _sessionValid(session) ? error.error : _sessionError,
      );
    } on FormatException {
      return Result.failure(
        !_sessionValid(session)
            ? _sessionError
            : const AppError(
                code: 'event_performer_decision_unconfirmed',
                message:
                    'Kararın doğrulanamadı. Davetlerini yenileyip kontrol et.',
              ),
      );
    } catch (_) {
      return Result.failure(
        !_sessionValid(session)
            ? _sessionError
            : const AppError(
                code: 'event_performer_decision_unknown',
                message: 'Etkinlik onayı güncellenemedi.',
              ),
      );
    }
  }
}
