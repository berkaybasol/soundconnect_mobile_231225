import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/backstage_feed_session.dart';
import '../domain/musician_feed_models.dart';
import '../domain/musician_feed_muted_authors.dart';
import '../domain/musician_feed_muted_authors_repository.dart';

class MusicianFeedMutedAuthorsRepositoryImpl
    implements MusicianFeedMutedAuthorsRepository {
  MusicianFeedMutedAuthorsRepositoryImpl(
    this._api,
    this._sessions, {
    this.onUnmuted,
  });

  final ApiClient _api;
  final AuthSessionManager _sessions;
  final void Function(MusicianFeedAuthorProfileIdentity author)? onUnmuted;
  static const _invalid = AppError(
    code: 'musician_feed_muted_authors_invalid',
    message: 'Sessize alınan hesaplar doğrulanamadı.',
  );
  static const _sessionChanged = AppError(
    code: 'musician_feed_muted_authors_session_changed',
    message: 'Hesabın değişti. Lütfen yeniden dene.',
  );
  static const _unknown = AppError(
    code: 'musician_feed_muted_authors_unavailable',
    message: 'İşlem tamamlanamadı. Lütfen tekrar dene.',
  );

  BackstageFeedIdentity? get _identity =>
      backstageFeedSessionIdentity(_sessions.session);

  @override
  Future<Result<MusicianFeedMutedAuthorsPage>> load({
    int limit = 30,
    String? cursor,
  }) {
    final normalized = cursor?.trim();
    if (limit < 1 ||
        limit > 50 ||
        (normalized != null &&
            (normalized.isEmpty || normalized.length > 4096))) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.get,
      '/muted-authors',
      query: {'limit': limit, if (normalized != null) 'cursor': normalized},
      decoder: MusicianFeedMutedAuthorsPage.fromJson,
    );
  }

  @override
  Future<Result<void>> unmute({
    required String profileType,
    required String profileId,
  }) async {
    final author = parseMusicianFeedAuthorProfileIdentity(
      profileType: profileType,
      profileId: profileId,
    );
    if (author == null) return const Result.failure(_invalid);
    final identity = _identity;
    final result = await _request<void>(
      ApiHttpMethod.delete,
      '/authors/${Uri.encodeComponent(author.profileType)}/${Uri.encodeComponent(author.profileId)}/mute',
      decoder: (_) {},
    );
    if (identity == null || identity != _identity) {
      return const Result.failure(_sessionChanged);
    }
    if (result.isSuccess) {
      // Repository lifetime outlives the management screen: returning during
      // DELETE must still invalidate a live feed after the server commits it.
      try {
        onUnmuted?.call(author);
      } catch (_) {
        /* The remote write succeeded. */
      }
    }
    return result;
  }

  Future<Result<T>> _request<T>(
    ApiHttpMethod method,
    String suffix, {
    required T Function(Object?) decoder,
    Map<String, dynamic>? query,
  }) async {
    final identity = _identity;
    if (identity == null) return const Result.failure(_sessionChanged);
    try {
      final response = await _api.request<T>(
        method,
        '${identity.audience.apiPath}$suffix',
        query: query,
        requestContext: ApiRequestContext(
          expectedSessionKey: identity.userId,
          expectedToken: identity.token,
        ),
        decoder: decoder,
      );
      return identity == _identity
          ? Result.success(response)
          : const Result.failure(_sessionChanged);
    } on ApiException catch (error) {
      return Result.failure(
        identity == _identity ? error.error : _sessionChanged,
      );
    } on FormatException {
      return Result.failure(identity == _identity ? _invalid : _sessionChanged);
    } catch (_) {
      return Result.failure(identity == _identity ? _unknown : _sessionChanged);
    }
  }
}
