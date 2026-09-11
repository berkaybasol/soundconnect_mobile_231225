import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/musician_feed_models.dart';
import '../domain/musician_feed_repository.dart';

class MusicianFeedRepositoryImpl implements MusicianFeedRepository {
  MusicianFeedRepositoryImpl(this._api, this._sessions);

  static const String _path = '/api/v1/feed/musician';
  static const int _maximumCursorLength = 4096;
  static final String _supportedItemTypes = MusicianFeedItemType.values
      .map((type) => type.apiValue)
      .join(',');

  static const AppError _sessionChanged = AppError(
    code: 'musician_feed_session_changed',
    message: 'Hesabın değişti. Akış yenileniyor.',
  );
  static const AppError _invalidRequest = AppError(
    code: 'musician_feed_invalid_request',
    message: 'Akış isteği geçersiz.',
  );
  static const AppError _invalidResponse = AppError(
    code: 'musician_feed_invalid_response',
    message: 'Akış yanıtı doğrulanamadı.',
  );
  static const AppError _unavailable = AppError(
    code: 'musician_feed_unavailable',
    message: 'Akış şu anda yüklenemiyor. Lütfen tekrar dene.',
  );
  static const AppError _featureUnavailable = AppError(
    code: musicianFeedFeatureUnavailableCode,
    message: 'Backstage akışı bu sürümde henüz açık değil.',
  );
  static const AppError _cursorInvalid = AppError(
    code: musicianFeedCursorInvalidCode,
    message: 'Akış güncellendi. Yeni içerikler yükleniyor.',
  );
  static const AppError _feedbackUnavailable = AppError(
    code: 'musician_feed_feedback_unavailable',
    message: 'Akış tercihin kaydedilemedi.',
  );

  final ApiClient _api;
  final AuthSessionManager _sessions;

  ({String userId, String token})? get _identity {
    final session = _sessions.session;
    final userId = session.userId?.trim() ?? '';
    final token = session.token?.trim() ?? '';
    if (!session.isAuthenticated ||
        !session.isActive ||
        userId.isEmpty ||
        token.isEmpty) {
      return null;
    }
    return (userId: userId, token: token);
  }

  bool _sameIdentity(({String userId, String token}) expected) {
    final current = _identity;
    return current != null &&
        current.userId == expected.userId &&
        current.token == expected.token;
  }

  ApiRequestContext _context(({String userId, String token}) identity) {
    return ApiRequestContext(
      expectedSessionKey: identity.userId,
      expectedToken: identity.token,
    );
  }

  @override
  Future<Result<MusicianFeedPage>> load({
    required int limit,
    String? cursor,
  }) async {
    final identity = _identity;
    final normalizedCursor = cursor?.trim();
    if (identity == null) return const Result.failure(_sessionChanged);
    if (limit < 1 ||
        limit > 30 ||
        (normalizedCursor != null &&
            (normalizedCursor.isEmpty ||
                normalizedCursor.length > _maximumCursorLength))) {
      return const Result.failure(_invalidRequest);
    }
    try {
      final page = await _api.request<MusicianFeedPage>(
        ApiHttpMethod.get,
        _path,
        query: {
          'limit': limit,
          'supportedItemTypes': _supportedItemTypes,
          if (normalizedCursor != null) 'cursor': normalizedCursor,
        },
        requestContext: _context(identity),
        decoder: MusicianFeedPage.fromJson,
      );
      if (!_sameIdentity(identity)) {
        return const Result.failure(_sessionChanged);
      }
      return Result.success(page);
    } on ApiException catch (error) {
      if (!_sameIdentity(identity)) {
        return const Result.failure(_sessionChanged);
      }
      if (normalizedCursor != null && _isCursorInvalid(error.error)) {
        return const Result.failure(_cursorInvalid);
      }
      if (normalizedCursor == null && _isEndpointUnavailable(error.error)) {
        return const Result.failure(_featureUnavailable);
      }
      return Result.failure(error.error);
    } on MusicianFeedFormatException {
      return Result.failure(
        _sameIdentity(identity) ? _invalidResponse : _sessionChanged,
      );
    } catch (_) {
      return Result.failure(
        _sameIdentity(identity) ? _unavailable : _sessionChanged,
      );
    }
  }

  static bool _isEndpointUnavailable(AppError error) {
    final code = error.code.trim().toLowerCase();
    return code == '404' ||
        code == '4006' ||
        code == 'endpoint_not_found' ||
        code == 'musician_feed_disabled';
  }

  static bool _isCursorInvalid(AppError error) {
    final code = error.code.trim().toLowerCase();
    return code == '1318' || code == 'musician_feed_cursor_invalid';
  }

  @override
  Future<Result<void>> sendFeedback({
    required String itemId,
    required String impressionToken,
    required MusicianFeedFeedbackAction action,
    String? reason,
  }) {
    final id = itemId.trim();
    final token = impressionToken.trim();
    final normalizedReason = reason?.trim();
    if (id.isEmpty ||
        id.length > 256 ||
        token.isEmpty ||
        token.length > 4096 ||
        (normalizedReason != null && normalizedReason.length > 500)) {
      return Future.value(const Result.failure(_invalidRequest));
    }
    return _mutation(
      ApiHttpMethod.post,
      '$_path/items/${Uri.encodeComponent(id)}/feedback',
      body: {
        'action': action.apiValue,
        if (normalizedReason?.isNotEmpty == true) 'reason': normalizedReason,
        'impressionToken': token,
      },
    );
  }

  @override
  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  }) {
    final eventId = clientEventId.trim();
    final token = impressionToken.trim();
    if (!_uuidPattern.hasMatch(eventId) ||
        token.isEmpty ||
        token.length > 4096) {
      return Future.value(const Result.failure(_invalidRequest));
    }
    return _mutation(
      ApiHttpMethod.post,
      '$_path/events',
      body: {
        'clientEventId': eventId,
        'impressionToken': token,
        'eventType': eventType.apiValue,
        if (occurredAt != null)
          'occurredAt': occurredAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<Result<void>> muteAuthor({
    required String profileType,
    required String profileId,
  }) {
    final author = parseMusicianFeedAuthorProfileIdentity(
      profileType: profileType,
      profileId: profileId,
    );
    if (author == null) {
      return Future.value(const Result.failure(_invalidRequest));
    }
    return _mutation(
      ApiHttpMethod.put,
      '$_path/authors/${Uri.encodeComponent(author.profileType)}/${Uri.encodeComponent(author.profileId)}/mute',
    );
  }

  @override
  Future<Result<void>> unmuteAuthor({
    required String profileType,
    required String profileId,
  }) {
    final author = parseMusicianFeedAuthorProfileIdentity(
      profileType: profileType,
      profileId: profileId,
    );
    if (author == null) {
      return Future.value(const Result.failure(_invalidRequest));
    }
    return _mutation(
      ApiHttpMethod.delete,
      '$_path/authors/${Uri.encodeComponent(author.profileType)}/${Uri.encodeComponent(author.profileId)}/mute',
    );
  }

  Future<Result<void>> _mutation(
    ApiHttpMethod method,
    String path, {
    Object? body,
  }) async {
    final identity = _identity;
    if (identity == null) return const Result.failure(_sessionChanged);
    try {
      await _api.request<Object?>(
        method,
        path,
        body: body,
        requestContext: _context(identity),
        decoder: (_) => null,
      );
      if (!_sameIdentity(identity)) {
        return const Result.failure(_sessionChanged);
      }
      return const Result.success(null);
    } on ApiException catch (error) {
      return Result.failure(
        _sameIdentity(identity) ? error.error : _sessionChanged,
      );
    } catch (_) {
      return Result.failure(
        _sameIdentity(identity) ? _feedbackUnavailable : _sessionChanged,
      );
    }
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
  );
}
