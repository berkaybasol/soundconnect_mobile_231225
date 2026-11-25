import '../../../core/auth/auth_session.dart';
import '../../../core/error/result.dart';

enum AccountDeletionProfile { listener, musician, venue, studio }

AccountDeletionProfile? accountDeletionProfile(AuthSession session) {
  final roles =
      session.normalizedRoles
          .map((role) => role.replaceFirst(RegExp(r'^ROLE_'), ''))
          .toSet()
        ..remove('USER');
  final hasManagementAccess = session.permissions.any((value) {
    final permission = value.trim().toUpperCase();
    return permission == 'READ_USERS' ||
        permission == 'ADMIN_PANEL_ACCESS' ||
        permission.startsWith('MANAGE_');
  });
  if (!session.isAuthenticated ||
      !session.isActive ||
      session.userId?.trim().isNotEmpty != true ||
      session.sessionScope != null ||
      session.isAdmin ||
      hasManagementAccess ||
      roles.length != 1) {
    return null;
  }
  return switch (roles.single) {
    'LISTENER' => AccountDeletionProfile.listener,
    'MUSICIAN' => AccountDeletionProfile.musician,
    'VENUE' => AccountDeletionProfile.venue,
    'STUDIO' => AccountDeletionProfile.studio,
    _ => null,
  };
}

typedef BandSuccessor = ({String userId, String username});
typedef BandDeletionOption = ({
  String bandId,
  String bandName,
  List<BandSuccessor> successors,
});
typedef BandDeletionDecision = ({String bandId, String? successorUserId});

abstract class AccountDeletionRepository {
  Future<Result<List<BandDeletionOption>>> getBandOptions(
    AuthSession expectedSession,
  );

  /// Confirmed erasure ends the matching local session, even if its UI closed.
  Future<Result<bool>> deleteAccount({
    required AuthSession expectedSession,
    String? currentPassword,
    String? googleIdToken,
    List<BandDeletionDecision> bandDecisions = const [],
  });
}
