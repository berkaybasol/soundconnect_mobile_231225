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
  Future<Result<List<BandDeletionOption>>> getBandOptions(
    AuthSession expectedSession,
  ) async {
    final revision = _sessions.credentialRevision;
    bool current() =>
        identical(_sessions.session, expectedSession) &&
        _sessions.credentialRevision == revision;
    if (!current() ||
        accountDeletionProfile(expectedSession) !=
            AccountDeletionProfile.musician) {
      return const Result.failure(_changed);
    }
    try {
      final result = await _api.request<List<BandDeletionOption>>(
        ApiHttpMethod.get,
        '/api/v1/user/bands/account-deletion-options',
        requestContext: ApiRequestContext(
          expectedSessionKey: expectedSession.userId,
          expectedToken: expectedSession.token,
          expectedCredentialRevision: revision,
        ),
        decoder: _decodeBandOptions,
      );
      return current()
          ? Result.success(result)
          : const Result.failure(_changed);
    } on ApiException catch (e) {
      return Result.failure(current() ? e.error : _changed);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'account_deletion_band_options',
          message: 'Band üyeliklerin yüklenemedi. Tekrar dene.',
        ),
      );
    }
  }

  static List<BandDeletionOption> _decodeBandOptions(Object? json) {
    String field(Map row, String key) {
      final value = row[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid band option field: $key');
      }
      return value;
    }

    final ids = <String>{};
    return (json as List)
        .map<BandDeletionOption>((value) {
          final row = value as Map;
          final id = field(row, 'bandId');
          if (!ids.add(id)) throw const FormatException('Duplicate band');
          final memberIds = <String>{};
          final successors = (row['successors'] as List)
              .map<BandSuccessor>((value) {
                final member = value as Map;
                final userId = field(member, 'userId');
                if (!memberIds.add(userId)) {
                  throw const FormatException('Duplicate successor');
                }
                return (userId: userId, username: field(member, 'username'));
              })
              .toList(growable: false);
          return (
            bandId: id,
            bandName: field(row, 'bandName'),
            successors: successors,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<Result<bool>> deleteAccount({
    required AuthSession expectedSession,
    String? currentPassword,
    String? googleIdToken,
    List<BandDeletionDecision> bandDecisions = const [],
  }) async {
    final revision = _sessions.credentialRevision;
    bool current() =>
        identical(_sessions.session, expectedSession) &&
        _sessions.credentialRevision == revision;
    if (!current()) {
      return const Result.failure(_changed);
    }
    final profile = accountDeletionProfile(expectedSession);
    if (profile == null ||
        (bandDecisions.isNotEmpty &&
            profile != AccountDeletionProfile.musician)) {
      return const Result.failure(
        AppError(
          code: '1007',
          message: 'Bu hesap için silme işlemi kullanılamıyor.',
        ),
      );
    }
    final credential = {
      if (currentPassword != null) 'currentPassword': currentPassword,
      if (googleIdToken != null) 'googleIdToken': googleIdToken,
    };
    if (credential.length != 1 || credential.values.single.trim().isEmpty) {
      return const Result.failure(
        AppError(
          code: '1006',
          message: 'Silme işlemini hesabının giriş yöntemiyle doğrula.',
        ),
      );
    }
    try {
      final confirmed = await _api.request<bool>(
        ApiHttpMethod.delete,
        '/api/v1/users/me/account',
        body: {
          'confirmation': 'DELETE',
          ...credential,
          if (bandDecisions.isNotEmpty)
            'bandDecisions': [
              for (final decision in bandDecisions)
                {
                  'bandId': decision.bandId,
                  'action': decision.successorUserId == null
                      ? 'CLOSE'
                      : 'TRANSFER',
                  if (decision.successorUserId != null)
                    'successorUserId': decision.successorUserId,
                },
            ],
        },
        requestContext: ApiRequestContext(
          expectedSessionKey: expectedSession.userId,
          expectedToken: expectedSession.token,
          expectedCredentialRevision: revision,
        ),
        decoder: (json) {
          if (json != true) throw const FormatException('Unconfirmed erasure');
          return true;
        },
      );
      final active = _sessions.session;
      if (_sessions.credentialRevision != revision ||
          active.userId != expectedSession.userId ||
          active.token != expectedSession.token) {
        return const Result.failure(_changed);
      }
      if (confirmed) await _sessions.logout();
      return Result.success(confirmed);
    } on ApiException catch (e) {
      if (!current()) {
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
