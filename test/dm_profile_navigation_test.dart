import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/dm_profile_navigation.dart';

void main() {
  test('maps every target type to its authenticated owner profile route', () {
    expect(
      ownerProfileRouteFor(DmProfileTargetType.musician),
      AppRoutes.musicianProfile,
    );
    expect(
      ownerProfileRouteFor(DmProfileTargetType.venue),
      AppRoutes.venueProfile,
    );
    expect(
      ownerProfileRouteFor(DmProfileTargetType.studio),
      AppRoutes.studioProfile,
    );
    expect(
      ownerProfileRouteFor(DmProfileTargetType.listener),
      AppRoutes.listenerProfile,
    );
  });

  test('maps every supported target to its existing public profile route', () {
    final expectedRoutes = <DmProfileTargetType, String>{
      DmProfileTargetType.musician: AppRoutes.musicianPublicProfile,
      DmProfileTargetType.venue: AppRoutes.venuePublicProfile,
      DmProfileTargetType.studio: AppRoutes.studioPublicProfile,
    };

    for (final entry in expectedRoutes.entries) {
      final route = dmProfileRouteFor(
        DmProfileTarget(
          type: entry.key,
          id: '${entry.key.name}-1',
          displayName: 'Test',
          imageUrl: null,
        ),
      );
      expect(route?.routeName, entry.value);
      expect(route?.arguments.profileId, '${entry.key.name}-1');
    }
  });

  test('listener target explicitly has no public navigation capability', () {
    final route = dmProfileRouteFor(
      const DmProfileTarget(
        type: DmProfileTargetType.listener,
        id: 'listener-1',
        displayName: 'Dinleyici',
        imageUrl: null,
      ),
    );

    expect(route, isNull);
  });
}
