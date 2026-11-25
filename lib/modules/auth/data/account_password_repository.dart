import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

enum AccountPasswordProvider { local, google }

class AccountPasswordRepository {
  AccountPasswordRepository(this._api, this._sessions);

  final ApiClient _api;
  final AuthSessionManager _sessions;
  static const _path = '/api/v1/users/me/password';
  static const _changed = AppError(
    code: 'password_session_changed',
    message: 'Oturum değişti. Hesap ayarlarını yeniden aç.',
  );

  ApiRequestContext _context(AuthSession session, int revision) =>
      ApiRequestContext(
        expectedToken: session.token,
        expectedSessionKey: session.userId,
        expectedCredentialRevision: revision,
      );

  Future<Result<AccountPasswordProvider>> provider(
    AuthSession session,
    int revision,
  ) async {
    try {
      final provider = await _api.request<AccountPasswordProvider>(
        ApiHttpMethod.get,
        _path,
        requestContext: _context(session, revision),
        decoder: (json) => switch (json) {
          {'provider': 'LOCAL'} => AccountPasswordProvider.local,
          {'provider': 'GOOGLE'} => AccountPasswordProvider.google,
          _ => throw const FormatException('Unknown account provider'),
        },
      );
      return Result.success(provider);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'password_provider',
          message: 'Giriş yöntemi doğrulanamadı. Tekrar dene.',
        ),
      );
    }
  }

  Future<Result<AuthSession>> change({
    required AuthSession session,
    required int revision,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final installed = await _sessions.rotateAccessToken(
        expected: session,
        revision: revision,
        requestToken: () => _api.request<String>(
          ApiHttpMethod.post,
          _path,
          body: {
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          },
          requestContext: _context(session, revision),
          decoder: (json) => switch (json) {
            {'token': final String token} => token,
            _ => throw const FormatException('Missing renewed session'),
          },
        ),
      );
      if (!installed ||
          _sessions.credentialRevision != revision + 1 ||
          _sessions.session.userId != session.userId) {
        return const Result.failure(_changed);
      }
      return Result.success(_sessions.session);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'password_change_unconfirmed',
          message: 'Şifre değişikliği doğrulanamadı.',
        ),
      );
    }
  }
}
