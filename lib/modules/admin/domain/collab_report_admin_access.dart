import '../../../core/auth/auth_session.dart';

const collabReportAdminPermission = 'MANAGE_COLLAB_REPORTS';

bool canManageCollabReports(AuthSession session) =>
    session.isActive &&
    session.token?.trim().isNotEmpty == true &&
    session.userId?.trim().isNotEmpty == true &&
    !session.isVenueApplicationSession &&
    !session.requiresListenerProfileChoice &&
    !session.hasAnyRole(const ['ROLE_LISTENER', 'LISTENER']) &&
    session.permissions.contains(collabReportAdminPermission);
