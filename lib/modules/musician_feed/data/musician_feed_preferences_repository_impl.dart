import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/musician_feed_preferences.dart';
import '../domain/musician_feed_preferences_repository.dart';

class MusicianFeedPreferencesRepositoryImpl
    implements MusicianFeedPreferencesRepository {
  MusicianFeedPreferencesRepositoryImpl(this._api, this._sessions);

  static const _path = '/api/v1/feed/musician/preferences';
  static const _invalid = AppError(
    code: 'musician_feed_preferences_invalid',
    message: 'Akış tercihi doğrulanamadı.',
  );
  static const _sessionChanged = AppError(
    code: 'musician_feed_preferences_session_changed',
    message: 'Hesabın değişti. Lütfen yeniden dene.',
  );
  static const _unknown = AppError(
    code: 'musician_feed_preferences_unknown',
    message: 'Akış tercihi şu anda güncellenemiyor.',
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

  bool _same(({String userId, String token}) expected) {
    final current = _identity;
    return current != null &&
        current.userId == expected.userId &&
        current.token == expected.token;
  }

  ApiRequestContext _context(({String userId, String token}) identity) =>
      ApiRequestContext(
        expectedSessionKey: identity.userId,
        expectedToken: identity.token,
      );

  @override
  Future<Result<MusicianFeedPreferences>> get() => _request(ApiHttpMethod.get);

  @override
  Future<Result<MusicianFeedPreferences>> updateOpportunityCity({
    required String? cityId,
    required int expectedVersion,
  }) {
    final normalizedCity = cityId?.trim();
    if (expectedVersion < 0 ||
        (normalizedCity != null &&
            (normalizedCity.isEmpty || normalizedCity.length > 64))) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.put,
      body: <String, dynamic>{
        'opportunityCityId': normalizedCity,
        'expectedVersion': expectedVersion,
      },
    );
  }

  Future<Result<MusicianFeedPreferences>> _request(
    ApiHttpMethod method, {
    Object? body,
  }) async {
    final identity = _identity;
    if (identity == null) return const Result.failure(_sessionChanged);
    try {
      final result = await _api.request<MusicianFeedPreferences>(
        method,
        _path,
        body: body,
        requestContext: _context(identity),
        decoder: MusicianFeedPreferences.fromJson,
      );
      return _same(identity)
          ? Result.success(result)
          : const Result.failure(_sessionChanged);
    } on ApiException catch (error) {
      return Result.failure(_same(identity) ? error.error : _sessionChanged);
    } on MusicianFeedPreferencesFormatException {
      return Result.failure(_same(identity) ? _invalid : _sessionChanged);
    } catch (_) {
      return Result.failure(_same(identity) ? _unknown : _sessionChanged);
    }
  }
}
