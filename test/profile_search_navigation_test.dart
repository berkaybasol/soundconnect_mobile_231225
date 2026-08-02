import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_search_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/navigation/profile_search_navigation.dart';

void main() {
  group('profile search navigation', () {
    test('opens owner routes for user-bound results owned by the viewer', () {
      const expectedRoutes = <ProfileSearchResultType, String>{
        ProfileSearchResultType.musician: AppRoutes.musicianProfile,
        ProfileSearchResultType.listener: AppRoutes.listenerProfile,
        ProfileSearchResultType.studio: AppRoutes.studioProfile,
        ProfileSearchResultType.venue: AppRoutes.venueProfile,
      };

      for (final entry in expectedRoutes.entries) {
        final destination = resolveProfileSearchDestination(
          result: _result(type: entry.key, userId: 'user-1'),
          currentUserId: ' user-1 ',
        );

        expect(destination?.route, entry.value);
        expect(destination?.opensOwnerProfile, isTrue);
      }
    });

    test('opens public routes when the result belongs to another user', () {
      const expectedRoutes = <ProfileSearchResultType, String>{
        ProfileSearchResultType.musician: AppRoutes.musicianPublicProfile,
        ProfileSearchResultType.band: AppRoutes.bandPublicProfile,
        ProfileSearchResultType.studio: AppRoutes.studioPublicProfile,
        ProfileSearchResultType.venue: AppRoutes.venuePublicProfile,
      };

      for (final entry in expectedRoutes.entries) {
        final destination = resolveProfileSearchDestination(
          result: _result(type: entry.key, userId: 'user-2'),
          currentUserId: 'user-1',
        );

        expect(destination?.route, entry.value);
        expect(destination?.opensOwnerProfile, isFalse);
      }
    });

    test('keeps bands public even when a user id happens to match', () {
      final destination = resolveProfileSearchDestination(
        result: _result(type: ProfileSearchResultType.band, userId: 'user-1'),
        currentUserId: 'user-1',
      );

      expect(destination?.route, AppRoutes.bandPublicProfile);
      expect(destination?.opensOwnerProfile, isFalse);
    });
  });
}

ProfileSearchResult _result({
  required ProfileSearchResultType type,
  required String? userId,
}) {
  return ProfileSearchResult(
    type: type,
    targetId: 'target-1',
    userId: userId,
    title: 'Profile',
    subtitle: null,
    imageUrl: null,
  );
}
