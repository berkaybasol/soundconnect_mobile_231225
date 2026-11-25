import '../../../core/auth/auth_session.dart';
import '../../../core/error/app_error.dart';

bool hasAdminPanelPermission(AuthSession session, String permission) =>
    session.isAuthenticated &&
    session.isActive &&
    session.isAdmin &&
    session.userId?.trim().isNotEmpty == true &&
    session.expiresAt?.isAfter(DateTime.now()) == true &&
    session.sessionScope == null &&
    !session.requiresListenerProfileChoice &&
    !session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) &&
    session.permissions.contains('ADMIN_PANEL_ACCESS') &&
    session.permissions.contains(permission);

bool canReadBacklineRequests(AuthSession session) =>
    hasAdminPanelPermission(session, 'MANAGE_BACKLINE_CATALOG');

bool canReadVenueSuggestions(AuthSession session) =>
    hasAdminPanelPermission(session, 'MANAGE_VENUES');

bool canManageTableReports(AuthSession session) =>
    hasAdminPanelPermission(session, 'MANAGE_TABLE_GROUP_REPORTS');

bool canManageContentReports(AuthSession session) =>
    hasAdminPanelPermission(session, 'MANAGE_CONTENT_REPORTS');

bool isAdminPanelAccessError(AppError? error) => const {
  '401',
  '403',
  '1008',
  '1101',
  '1102',
  '1103',
  'api_session_fence',
}.contains(error?.code.toLowerCase());
