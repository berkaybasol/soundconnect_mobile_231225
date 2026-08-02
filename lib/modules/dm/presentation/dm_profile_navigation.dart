import '../../../app/router/app_routes.dart';
import '../../profile/presentation/screens/profile_route_args.dart';
import '../domain/entities/dm_profile_target.dart';

class DmProfileRoute {
  const DmProfileRoute({required this.routeName, required this.arguments});

  final String routeName;
  final PublicProfileArgs arguments;
}

/// Returns the existing public profile surface for a resolved DM target.
///
/// Listener profiles currently have no public screen, so they intentionally
/// return `null`. Callers must keep non-profile actions (such as messaging)
/// available without guessing another profile type.
DmProfileRoute? dmProfileRouteFor(DmProfileTarget target) {
  final routeName = switch (target.type) {
    DmProfileTargetType.musician => AppRoutes.musicianPublicProfile,
    DmProfileTargetType.venue => AppRoutes.venuePublicProfile,
    DmProfileTargetType.studio => AppRoutes.studioPublicProfile,
    DmProfileTargetType.listener => null,
  };
  if (routeName == null) return null;
  return DmProfileRoute(
    routeName: routeName,
    arguments: PublicProfileArgs(profileId: target.id),
  );
}
