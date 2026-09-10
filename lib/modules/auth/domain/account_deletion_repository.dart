import '../../../core/auth/auth_session.dart';
import '../../../core/error/result.dart';

bool canDeleteListenerAccount(AuthSession session) {
  final roles = session.normalizedRoles
      .map((role) => role.replaceFirst(RegExp(r'^ROLE_'), ''))
      .toSet();
  return session.isAuthenticated &&
      session.isActive &&
      !session.isAdmin &&
      roles.length == 1 &&
      roles.contains('LISTENER');
}

abstract class AccountDeletionRepository {
  Future<Result<bool>> deleteListenerAccount({
    required AuthSession expectedSession,
    required String currentPassword,
  });
}
