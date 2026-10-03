import 'login_result.dart';
import 'user_status.dart';

/// Result of confirming a registration e-mail.
///
/// Active listeners receive their onboarding session. Verified venue applicants
/// may receive a separate signed application-only session; other account types
/// keep the established sign-in or approval flow.
class VerifyCodeResult {
  const VerifyCodeResult({this.listenerSession, this.venueApplicationSession});

  final LoginResult? listenerSession;
  final LoginResult? venueApplicationSession;
  LoginResult? get session => venueApplicationSession ?? listenerSession;
  bool get hasVenueApplicationSession =>
      venueApplicationSession?.sessionScope == 'VENUE_APPLICATION' &&
      venueApplicationSession?.applicationId != null &&
      venueApplicationSession!.token.isNotEmpty &&
      !venueApplicationSession!.requiresListenerProfileChoice;

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
