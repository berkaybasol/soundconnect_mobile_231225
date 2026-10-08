import '../../../core/auth/auth_session.dart';

const announcementManagementPermission = 'MANAGE_PROMOTIONS';
typedef AnnouncementSessionIdentity = ({String userId, String token});

AnnouncementSessionIdentity? announcementSessionIdentity(
  AuthSession session, {
  bool admin = false,
}) {
  if (!session.isAuthenticated ||
      !session.isActive ||
      session.requiresListenerProfileChoice ||
      session.userId?.trim().isNotEmpty != true ||
      session.token?.trim().isNotEmpty != true ||
      (admin &&
          !session.permissions.contains(announcementManagementPermission))) {
    return null;
  }
  return (userId: session.userId!.trim(), token: session.token!.trim());
}
