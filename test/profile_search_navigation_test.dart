import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/profile_search_result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
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
        ProfileSearchResultType.listener: AppRoutes.listenerPublicProfile,
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

    test('fails unknown listener visibility closed', () {
      final ghost = ProfileSearchResult.fromJson(<String, dynamic>{
        'type': 'LISTENER',
        'targetId': 'listener-1',
        'userId': 'user-1',
        'title': 'listener',
        'visibilityMode': 'GHOST',
      });
      final unknown = ProfileSearchResult.fromJson(<String, dynamic>{
        'type': 'LISTENER',
        'targetId': 'listener-2',
        'userId': 'user-2',
        'title': 'listener',
        'visibilityMode': 'FUTURE_MODE',
      });

      expect(ghost.visibilityMode, ListenerVisibilityMode.ghost);
      expect(ghost.isGhostListener, isTrue);
      expect(unknown.visibilityMode, ListenerVisibilityMode.ghost);
      expect(unknown.isGhostListener, isTrue);
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
