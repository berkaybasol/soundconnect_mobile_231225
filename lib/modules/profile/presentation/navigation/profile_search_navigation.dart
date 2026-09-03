import '../../../../app/router/app_routes.dart';
import '../../domain/entities/profile_search_result.dart';

class ProfileSearchDestination {
  final String route;
  final bool opensOwnerProfile;

  const ProfileSearchDestination({
    required this.route,
    required this.opensOwnerProfile,
  });
}

ProfileSearchDestination? resolveProfileSearchDestination({
  required ProfileSearchResult result,
  required String? currentUserId,
}) {
  final normalizedCurrentUserId = currentUserId?.trim() ?? '';
  final resultUserId = result.userId?.trim() ?? '';
  final isOwner =
      normalizedCurrentUserId.isNotEmpty &&
      resultUserId.isNotEmpty &&
      normalizedCurrentUserId == resultUserId;

  if (isOwner) {
    return switch (result.type) {
      ProfileSearchResultType.musician => const ProfileSearchDestination(
        route: AppRoutes.musicianProfile,
        opensOwnerProfile: true,
      ),
      ProfileSearchResultType.listener => const ProfileSearchDestination(
        route: AppRoutes.listenerProfile,
        opensOwnerProfile: true,
      ),
      ProfileSearchResultType.studio => const ProfileSearchDestination(
        route: AppRoutes.studioProfile,
        opensOwnerProfile: true,
      ),
      ProfileSearchResultType.venue => const ProfileSearchDestination(
        route: AppRoutes.venueProfile,
        opensOwnerProfile: true,
      ),
      ProfileSearchResultType.band => const ProfileSearchDestination(
        route: AppRoutes.bandPublicProfile,
        opensOwnerProfile: false,
      ),
      ProfileSearchResultType.unknown => null,
    };
  }

  return switch (result.type) {
    ProfileSearchResultType.musician => const ProfileSearchDestination(
      route: AppRoutes.musicianPublicProfile,
      opensOwnerProfile: false,
    ),
    ProfileSearchResultType.band => const ProfileSearchDestination(
      route: AppRoutes.bandPublicProfile,
      opensOwnerProfile: false,
    ),
    ProfileSearchResultType.studio => const ProfileSearchDestination(
      route: AppRoutes.studioPublicProfile,
      opensOwnerProfile: false,
    ),
    ProfileSearchResultType.venue => const ProfileSearchDestination(
      route: AppRoutes.venuePublicProfile,
      opensOwnerProfile: false,
    ),
    ProfileSearchResultType.listener => const ProfileSearchDestination(
      route: AppRoutes.listenerPublicProfile,
      opensOwnerProfile: false,
    ),
    ProfileSearchResultType.unknown => null,
  };
}
