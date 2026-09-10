import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/account_deletion_repository.dart';

class AccountDeletionRepositoryImpl implements AccountDeletionRepository {
  AccountDeletionRepositoryImpl(this._api, this._sessions);
  final ApiClient _api;
  final AuthSessionManager _sessions;

  static const _changed = AppError(
    code: 'account_deletion_session_changed',
    message: 'Oturum değişti. Hesap ayarlarını yeniden aç.',
  );

  @override
  Future<Result<bool>> deleteListenerAccount({
    required AuthSession expectedSession,
    required String currentPassword,
  }) async {
    if (!identical(_sessions.session, expectedSession)) {
      return const Result.failure(_changed);
    }
    if (!canDeleteListenerAccount(expectedSession)) {
      return const Result.failure(
        AppError(
          code: '1007',
          message: 'Bu işlem yalnızca dinleyici hesapları için kullanılabilir.',
        ),
      );
    }
    if (currentPassword.isEmpty) {
      return const Result.failure(
        AppError(
          code: '1006',
          message: 'Silme işlemini doğrulamak için mevcut şifreni gir.',
        ),
      );
    }
    try {
      final confirmed = await _api.request<bool>(
        ApiHttpMethod.delete,
        '/api/v1/users/me/account',
        body: {'confirmation': 'DELETE', 'currentPassword': currentPassword},
        requestContext: ApiRequestContext(
          expectedSessionKey: expectedSession.userId,
          expectedToken: expectedSession.token,
        ),
        decoder: (json) {
          if (json != true) throw const FormatException('Unconfirmed erasure');
          return true;
        },
      );
      if (!identical(_sessions.session, expectedSession)) {
        return const Result.failure(_changed);
      }
      return Result.success(confirmed);
    } on ApiException catch (e) {
      if (!identical(_sessions.session, expectedSession)) {
        return const Result.failure(_changed);
      }
      return Result.failure(e.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'account_deletion_uncertain',
          message:
              'Silme işleminin sonucu doğrulanamadı. Bağlantını kontrol edip yeniden dene.',
        ),
      );
    }
  }
}
