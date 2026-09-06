import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/event_performer_request.dart';
import '../domain/entities/event_profile_publication.dart';
import '../domain/event_profile_publication_repository.dart';
import 'models/event_profile_publication_model.dart';

class EventProfilePublicationRepositoryImpl
    implements EventProfilePublicationRepository {
  const EventProfilePublicationRepositoryImpl(
    this._api, {
    required String? Function() sessionKeyProvider,
    void Function()? onPublicationChanged,
  }) : _sessionKeyProvider = sessionKeyProvider,
       _onPublicationChanged = onPublicationChanged;

  static const _path = '/api/v1/user/event-profile-publications';
  final ApiClient _api;
  final String? Function() _sessionKeyProvider;
  final void Function()? _onPublicationChanged;

  String? get _session {
    final session = _sessionKeyProvider()?.trim() ?? '';
    return session.isEmpty ? null : session;
  }

  @override
  Future<Result<EventProfilePublicationPage>> listMine({
    required EventPerformerTargetType targetType,
    required String targetId,
    EventProfilePublicationPeriod period = EventProfilePublicationPeriod.all,
    int page = 0,
    int size = 20,
  }) async {
    final session = _session;
    if (session == null) return const Result.failure(_sessionChanged);
    final id = targetId.trim().toLowerCase();
    if (!EventProfilePublicationModel.isValidId(id) ||
        page < 0 ||
        page > 100 ||
        size < 1 ||
        size > 50) {
      return const Result.failure(_invalidRequest);
    }
    try {
      final result = await _api.request<EventProfilePublicationPage>(
        ApiHttpMethod.get,
        _path,
        query: {
          'targetType': targetType.wireValue,
          'targetId': id,
          if (period != EventProfilePublicationPeriod.all)
            'period': period.wireValue,
          'page': page,
          'size': size,
        },
        requestContext: ApiRequestContext(expectedSessionKey: session),
        decoder: (raw) => _decodePage(
          raw,
          targetType: targetType,
          targetId: id,
          requestedPage: page,
          requestedSize: size,
        ),
      );
      if (session != _session) return const Result.failure(_sessionChanged);
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(
        session != _session ? _sessionChanged : error.error,
      );
    } on FormatException {
      return Result.failure(
        session != _session ? _sessionChanged : _invalidResponse,
      );
    } catch (_) {
      return Result.failure(
        session != _session ? _sessionChanged : _unavailable,
      );
    }
  }

  @override
  Future<Result<EventProfilePublication>> setVisible({
    required String eventId,
    required EventPerformerTargetType targetType,
    required String targetId,
    required bool visible,
    required int version,
  }) async {
    final session = _session;
    if (session == null) return const Result.failure(_sessionChanged);
    final id = targetId.trim().toLowerCase();
    final event = eventId.trim().toLowerCase();
    if (!EventProfilePublicationModel.isValidId(id) ||
        !EventProfilePublicationModel.isValidId(event) ||
        version < 0 ||
        version >= EventProfilePublicationModel.maxSafeVersion) {
      return const Result.failure(_invalidRequest);
    }
    try {
      // Never retry a mutation here. On a lost response the caller must reload
      // this profile's authoritative state before making a new decision.
      final result = await _api.request<EventProfilePublication>(
        ApiHttpMethod.put,
        '$_path/${Uri.encodeComponent(event)}',
        body: {
          'targetType': targetType.wireValue,
          'targetId': id,
          'visible': visible,
          'version': version,
        },
        requestContext: ApiRequestContext(expectedSessionKey: session),
        decoder: (raw) {
          final item = EventProfilePublicationModel.fromJson(_object(raw));
          if (item.eventId != event ||
              item.targetId != id ||
              item.targetType != targetType ||
              item.visible != visible ||
              (item.version != version && item.version != version + 1)) {
            throw const FormatException(
              'Publication update was not confirmed.',
            );
          }
          return item;
        },
      );
      if (session != _session) return const Result.failure(_sessionChanged);
      try {
        _onPublicationChanged?.call();
      } catch (_) {
        // Refresh observers cannot undo an already confirmed server write.
      }
      return Result.success(result);
    } on ApiException catch (error) {
      return Result.failure(
        session != _session ? _sessionChanged : error.error,
      );
    } on FormatException {
      return Result.failure(
        session != _session ? _sessionChanged : _invalidResponse,
      );
    } catch (_) {
      return Result.failure(
        session != _session ? _sessionChanged : _unavailable,
      );
    }
  }

  static EventProfilePublicationPage _decodePage(
    Object? raw, {
    required EventPerformerTargetType targetType,
    required String targetId,
    required int requestedPage,
    required int requestedSize,
  }) {
    final json = _object(raw);
    final page = _integer(json['page'] ?? json['number']);
    final size = _integer(json['size']);
    final totalElements = _integer(json['totalElements']);
    final totalPages = _integer(json['totalPages']);
    final first = json['first'];
    final last = json['last'];
    final content = json['content'];
    if (page != requestedPage ||
        size != requestedSize ||
        (json['number'] != null && _integer(json['number']) != page) ||
        first is! bool ||
        last is! bool ||
        content is! List ||
        first != (page == 0) ||
        totalElements < 0 ||
        totalPages < 0) {
      throw const FormatException('Invalid publication page metadata.');
    }
    final expectedPages = totalElements == 0
        ? 0
        : ((totalElements - 1) ~/ size) + 1;
    final remaining = totalElements - page * size;
    final expectedCount = remaining.clamp(0, size);
    if (totalPages != expectedPages ||
        last != (totalPages == 0 || page + 1 >= totalPages) ||
        content.length > expectedCount) {
      throw const FormatException('Inconsistent publication page totals.');
    }
    // The server can safely omit an event that disappeared or became
    // ineligible between the page/count and detail queries. Keep its paging
    // metadata rather than interpreting fewer items as malformed consent.
    final items = <EventProfilePublication>[];
    final events = <String>{};
    for (final rawItem in content) {
      final item = EventProfilePublicationModel.fromJson(_object(rawItem));
      if (item.targetId != targetId ||
          item.targetType != targetType ||
          !events.add(item.eventId)) {
        throw const FormatException('Invalid publication page identity.');
      }
      items.add(item);
    }
    return EventProfilePublicationPage(
      items: List.unmodifiable(items),
      page: page,
      size: size,
      totalElements: totalElements,
      totalPages: totalPages,
      hasNext: !last,
    );
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected a publication object.');
    }
    return value;
  }

  static int _integer(Object? value) {
    if (value is! int ||
        value < 0 ||
        value > EventProfilePublicationModel.maxSafeVersion) {
      throw const FormatException('Expected a nonnegative integer.');
    }
    return value;
  }

  static const _sessionChanged = AppError(
    code: 'event_profile_publication_session_changed',
    message: 'Oturum değişti. Etkinliklerini yeniden açıp tekrar dene.',
  );
  static const _invalidRequest = AppError(
    code: 'event_profile_publication_invalid_request',
    message: 'Etkinlik tercihi geçersiz. Sayfayı yenileyip tekrar dene.',
  );
  static const _invalidResponse = AppError(
    code: 'event_profile_publication_invalid_response',
    message: 'Etkinlik tercihin doğrulanamadı. Sayfayı yenileyip tekrar dene.',
  );
  static const _unavailable = AppError(
    code: 'event_profile_publication_unavailable',
    message: 'Etkinlik tercihin alınamadı. Sayfayı yenileyip tekrar dene.',
  );
}
