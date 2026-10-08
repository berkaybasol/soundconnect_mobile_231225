import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_models.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/screens/marketplace_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';

import 'marketplace_test_support.dart';

void main() {
  late MarketplaceFakeRepository repository;
  RouteSettings? openedProfile;

  setUp(() async {
    await serviceLocator.reset();
    serviceLocator.registerSingleton<AuthSessionManager>(
      MarketplaceTestSessions(marketSession()),
      dispose: (value) => value.dispose(),
    );
    repository = MarketplaceFakeRepository();
    openedProfile = null;
  });
  tearDown(() async => serviceLocator.reset());

  Future<void> openDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        home: MarketplaceScreen(
          initialListingId: marketListingId,
          repository: repository,
          locationRepository: MarketplaceFakeLocations(),
        ),
        onGenerateRoute: (settings) {
          openedProfile = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Seller profile')),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('marketplace-seller-avatar')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  for (final type in ['MUSICIAN', 'STUDIO', 'VENUE']) {
    testWidgets(
      '$type seller renders its public avatar and keeps profile navigation',
      (tester) async {
        final url = 'https://cdn.example.test/avatars/$type.jpg';
        repository.current = _listing(type, url);
        await openDetail(tester);
        final avatar = find.byKey(const Key('marketplace-seller-avatar'));
        final image = tester.widget<AppCachedNetworkImage>(
          find.descendant(
            of: avatar,
            matching: find.byType(AppCachedNetworkImage),
          ),
        );
        expect(image.imageUrl, url);
        expect(image.fit, BoxFit.cover);
        expect(image.cacheWidth, 150);
        expect(image.cacheHeight, 150);
        expect(image.persistentCache, isTrue);
        expect(
          find.descendant(of: avatar, matching: find.byType(ClipOval)),
          findsOneWidget,
        );
        await tester.tap(avatar);
        await tester.pumpAndSettle();
        expect(openedProfile?.name, switch (type) {
          'STUDIO' => AppRoutes.studioPublicProfile,
          'VENUE' => AppRoutes.venuePublicProfile,
          _ => AppRoutes.musicianPublicProfile,
        });
        final args = openedProfile!.arguments;
        expect(
          type == 'VENUE'
              ? (args as VenuePublicProfileArgs).venueId
              : (args as PublicProfileArgs).profileId,
          marketSellerId,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing blank and unusable seller avatars retain the initial fallback',
    (tester) async {
      for (final url in <String?>[null, '   ', 'file:///private/avatar.jpg']) {
        repository.current = _listing('MUSICIAN', url);
        await openDetail(tester);
        final avatar = find.byKey(const Key('marketplace-seller-avatar'));
        expect(
          find.descendant(of: avatar, matching: find.text('D')),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'refresh uses the current avatar URL instead of an old seller image',
    (tester) async {
      repository.current = _listing('MUSICIAN', null);
      await openDetail(tester);
      expect(find.byType(AppCachedNetworkImage), findsNothing);
      const newUrl = 'https://cdn.example.test/avatars/updated.jpg';
      repository.current = _listing('MUSICIAN', newUrl);
      await tester.tap(find.byTooltip('Yenile'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('marketplace-seller-avatar')),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AppCachedNetworkImage>(find.byType(AppCachedNetworkImage))
            .imageUrl,
        newUrl,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

MarketplaceListing _listing(String type, String? avatarUrl) {
  final json = marketListingJson(isOwner: true);
  return MarketplaceListing.fromJson({
    ...json,
    'seller': {
      ...json['seller'] as Map<String, dynamic>,
      'profileType': type,
      'avatarUrl': avatarUrl,
    },
  });
}
