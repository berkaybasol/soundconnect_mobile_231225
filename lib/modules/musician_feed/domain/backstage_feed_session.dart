import '../../../core/auth/auth_session.dart';

enum BackstageFeedAudience {
  musician('musician'),
  venue('venue'),
  studio('studio'),
  listener('listener');

  const BackstageFeedAudience(this.pathSegment);

  final String pathSegment;
  String get apiPath => '/api/v1/feed/$pathSegment';
  bool get supportsProfileCompletion => this == musician;
}

typedef BackstageFeedIdentity = ({
  String userId,
  String token,
  BackstageFeedAudience audience,
});

/// One authenticated profile audience owns both feed reads and mutations.
/// Ambiguous roles never fall back to another profile's feed endpoint.
BackstageFeedIdentity? backstageFeedSessionIdentity(AuthSession session) {
  final userId = session.userId?.trim() ?? '';
  final token = session.token?.trim() ?? '';
  if (!session.isAuthenticated ||
      !session.isActive ||
      session.requiresListenerProfileChoice ||
      userId.isEmpty ||
      token.isEmpty) {
    return null;
  }
  final profileRoles = session.normalizedRoles
      .map((role) => role.startsWith('ROLE_') ? role.substring(5) : role)
      .where(
        const {
          'MUSICIAN',
          'VENUE',
          'LISTENER',
          'STUDIO',
          'ORGANIZER',
          'PRODUCER',
        }.contains,
      )
      .toSet();
  if (profileRoles.length != 1) return null;
  final audience = switch (profileRoles.single) {
    'MUSICIAN' => BackstageFeedAudience.musician,
    'VENUE' => BackstageFeedAudience.venue,
    'STUDIO' => BackstageFeedAudience.studio,
    'LISTENER' => BackstageFeedAudience.listener,
    _ => null,
  };
  if (audience == null) return null;
  return (userId: userId, token: token, audience: audience);
}
