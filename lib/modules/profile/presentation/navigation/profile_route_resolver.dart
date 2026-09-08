import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/band_repository.dart';
import '../../domain/listener_profile_repository.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/studio_profile_repository.dart';
import '../../domain/venue_profile_repository.dart';
import '../screens/band_profile_screen.dart';
import '../screens/profile_route_args.dart';

enum ProfileRouteKind { musician, band, venue, studio, listener }

class ProfileRouteTarget {
  final ProfileRouteKind kind;
  final String id;
  final String? sourceEventId;

  const ProfileRouteTarget({
    required this.kind,
    required this.id,
    this.sourceEventId,
  });

  factory ProfileRouteTarget.fromArguments(
    ProfileRouteKind kind,
    Object? args,
  ) {
    String? id;
    String? sourceEventId;
    if (args is PublicProfileArgs && kind != ProfileRouteKind.band) {
      // DM's venue target is the venue ID, despite the legacy argument name.
      id = args.profileId;
    } else if (args is VenuePublicProfileArgs &&
        kind == ProfileRouteKind.venue) {
      id = args.venueId;
      sourceEventId = args.sourceEventId;
    } else if (args is BandProfileScreenArgs && kind == ProfileRouteKind.band) {
      id = args.bandId;
    } else if (args is String) {
      id = args;
    } else if (args is Map) {
      final key = switch (kind) {
        ProfileRouteKind.band => 'bandId',
        ProfileRouteKind.venue => 'venueId',
        _ => 'profileId',
      };
      final value = args[key];
      if (value is String) id = value;
      if (kind == ProfileRouteKind.venue && args['sourceEventId'] is String) {
        sourceEventId = args['sourceEventId'] as String;
      }
    }
    return ProfileRouteTarget(
      kind: kind,
      id: id?.trim() ?? '',
      sourceEventId: sourceEventId?.trim().isNotEmpty == true
          ? sourceEventId!.trim()
          : null,
    );
  }

  Object get publicArguments => switch (kind) {
    ProfileRouteKind.band => BandProfileScreenArgs(
      bandId: id,
      viewMode: BandProfileViewMode.public,
    ),
    ProfileRouteKind.venue => VenuePublicProfileArgs(
      venueId: id,
      sourceEventId: sourceEventId,
    ),
    _ => PublicProfileArgs(profileId: id),
  };

  String get publicRoute => switch (kind) {
    ProfileRouteKind.musician => AppRoutes.musicianPublicProfile,
    ProfileRouteKind.band => AppRoutes.bandPublicProfile,
    ProfileRouteKind.venue => AppRoutes.venuePublicProfile,
    ProfileRouteKind.studio => AppRoutes.studioPublicProfile,
    ProfileRouteKind.listener => AppRoutes.listenerPublicProfile,
  };

  bool canResolveOwnership(AuthSession session) =>
      session.isAuthenticated &&
      session.isActive &&
      (session.userId?.trim().isNotEmpty ?? false) &&
      session.hasAnyRole(switch (kind) {
        ProfileRouteKind.musician ||
        ProfileRouteKind.band => const ['MUSICIAN', 'ROLE_MUSICIAN'],
        ProfileRouteKind.venue => const ['VENUE', 'ROLE_VENUE'],
        ProfileRouteKind.studio => const ['STUDIO', 'ROLE_STUDIO'],
        ProfileRouteKind.listener => const ['LISTENER', 'ROLE_LISTENER'],
      });
}

class ProfileRouteDestination {
  final String route;
  final Object? arguments;

  const ProfileRouteDestination(this.route, {this.arguments});
}

/// Public route names express a target, not a user's relationship to it.
/// Resolve that relationship using authenticated IDs before building the page.
/// No cached ownership survives a session change or band membership change.
class ProfileRouteResolver {
  const ProfileRouteResolver();

  Future<ProfileRouteDestination?> resolve(
    ProfileRouteTarget target,
    AuthSession session,
  ) async {
    if (target.id.isEmpty) {
      throw const FormatException('Missing profile target');
    }
    if (!target.canResolveOwnership(session)) return null;
    final viewerId = session.userId!.trim();
    switch (target.kind) {
      case ProfileRouteKind.musician:
        final result = await serviceLocator<MusicianProfileRepository>()
            .getMyProfile();
        final profile = result.data;
        if (!result.isSuccess ||
            profile == null ||
            profile.id.trim().isEmpty ||
            profile.userId.trim() != viewerId) {
          throw StateError('Musician identity could not be verified');
        }
        return profile.id.trim() == target.id
            ? const ProfileRouteDestination(AppRoutes.musicianProfile)
            : null;
      case ProfileRouteKind.studio:
        final result = await serviceLocator<StudioProfileRepository>()
            .getMyProfile();
        final profile = result.data;
        if (!result.isSuccess ||
            profile == null ||
            profile.id.trim().isEmpty ||
            profile.userId.trim() != viewerId) {
          throw StateError('Studio identity could not be verified');
        }
        return profile.id.trim() == target.id
            ? const ProfileRouteDestination(AppRoutes.studioProfile)
            : null;
      case ProfileRouteKind.listener:
        final result = await serviceLocator<ListenerProfileRepository>()
            .getMyProfile();
        final profile = result.data;
        if (!result.isSuccess ||
            profile == null ||
            profile.id.trim().isEmpty ||
            profile.userId.trim() != viewerId) {
          throw StateError('Listener identity could not be verified');
        }
        return profile.id.trim() == target.id
            ? const ProfileRouteDestination(AppRoutes.listenerProfile)
            : null;
      case ProfileRouteKind.venue:
        final result = await serviceLocator<VenueProfileRepository>()
            .getPublicVenueProfile(venueId: target.id);
        final profile = result.data;
        if (!result.isSuccess ||
            profile == null ||
            profile.venueId.trim() != target.id ||
            profile.ownerUserId.trim().isEmpty) {
          throw StateError('Venue identity could not be verified');
        }
        return profile.ownerUserId.trim() == viewerId
            ? ProfileRouteDestination(
                AppRoutes.venueProfile,
                arguments: VenueProfileArgs(venueId: target.id),
              )
            : null;
      case ProfileRouteKind.band:
        final result = await serviceLocator<BandRepository>().getPublicBandById(
          target.id,
        );
        final profile = result.data;
        if (!result.isSuccess ||
            profile == null ||
            profile.id.trim() != target.id) {
          throw StateError('Band membership could not be verified');
        }
        final memberships = profile.members
            .where(
              (member) =>
                  member.userId.trim() == viewerId &&
                  member.status.trim().toUpperCase() == 'ACTIVE',
            )
            .toList();
        if (memberships.isEmpty) return null;
        if (memberships.length != 1) {
          throw StateError('Ambiguous band membership');
        }
        final founder = memberships.single.isFounder;
        return ProfileRouteDestination(
          founder ? AppRoutes.bandProfile : AppRoutes.bandMemberProfile,
          arguments: BandProfileScreenArgs(
            bandId: target.id,
            viewMode: founder
                ? BandProfileViewMode.auto
                : BandProfileViewMode.member,
          ),
        );
    }
  }
}
