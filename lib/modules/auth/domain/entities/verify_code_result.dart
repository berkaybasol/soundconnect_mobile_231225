import 'login_result.dart';
import 'user_status.dart';

/// Result of confirming a registration e-mail.
///
/// Only a newly verified, active listener is allowed to receive [listenerSession].
/// Other account types keep the established sign-in or approval flow.
class VerifyCodeResult {
  const VerifyCodeResult({this.listenerSession});

  final LoginResult? listenerSession;

  bool get requiresListenerProfileChoice {
    final session = listenerSession;
    if (session == null ||
        session.token.trim().isEmpty ||
        session.status != UserStatus.active) {
      return false;
    }
    final isListener = session.roles.any((role) {
      final normalized = role.trim().toUpperCase();
      return normalized == 'ROLE_LISTENER' || normalized == 'LISTENER';
    });
    return isListener && session.requiresListenerProfileChoice;
  }
}
