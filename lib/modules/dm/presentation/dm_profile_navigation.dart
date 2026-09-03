import '../../../app/router/app_routes.dart';
import '../../profile/presentation/screens/profile_route_args.dart';
import '../domain/entities/dm_profile_target.dart';

class DmProfileRoute {
  const DmProfileRoute({required this.routeName, required this.arguments});

  final String routeName;
  final PublicProfileArgs arguments;
}

/// Returns the authenticated user's editable/owner profile surface.
String ownerProfileRouteFor(DmProfileTargetType type) => switch (type) {
  DmProfileTargetType.musician => AppRoutes.musicianProfile,
  DmProfileTargetType.venue => AppRoutes.venueProfile,
  DmProfileTargetType.studio => AppRoutes.studioProfile,
  DmProfileTargetType.listener => AppRoutes.listenerProfile,
};

/// Returns the public profile surface for a resolved DM target.
DmProfileRoute? dmProfileRouteFor(DmProfileTarget target) {
  final routeName = switch (target.type) {
    DmProfileTargetType.musician => AppRoutes.musicianPublicProfile,
    DmProfileTargetType.venue => AppRoutes.venuePublicProfile,
    DmProfileTargetType.studio => AppRoutes.studioPublicProfile,
    DmProfileTargetType.listener => AppRoutes.listenerPublicProfile,
  };
  return DmProfileRoute(
    routeName: routeName,
    arguments: PublicProfileArgs(profileId: target.id),
  );
}
