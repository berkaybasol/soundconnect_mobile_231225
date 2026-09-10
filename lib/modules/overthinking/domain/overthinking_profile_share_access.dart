import '../../../core/auth/auth_session.dart';
import '../../../core/auth/listener_profile_publication_access.dart';

bool canShareOverthinkingOnProfile(AuthSession? session) =>
    canPublishListenerProfile(session);
