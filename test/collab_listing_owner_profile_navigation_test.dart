import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_types.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/entities/collab_actor.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/cubit/collab_listing_detail_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/screens/collab_listing_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/widgets/collab_discovery_widgets.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/collab_test_support.dart';

const _heroKey = Key('collab-listing-publisher-profile');
const _ownerAvatarKey = Key('collab-owner-avatar-profile');
const _ownerNameKey = Key('collab-owner-name-profile');
const _ownerCardKey = Key('collab-owner-card');

void main() {
  for (final kind in CollabProfileKind.values) {
    for (final target in _ProfileTap.values) {
      testWidgets('${kind.name} ${target.name} opens the publisher profile', (
        tester,
      ) async {
        final actor = _actor(kind);
        final openedRoutes = <RouteSettings>[];
        await _pumpDetail(tester, actor, openedRoutes);
        final targetFinder = _profileTapFinder(target, actor);
        await _revealProfileTarget(tester, target, targetFinder);

        await tester.tap(targetFinder);
        await tester.pumpAndSettle();

        expect(openedRoutes, hasLength(1));
        _expectPublisherRoute(openedRoutes.single, actor);
        expect(find.text('Profili görüntüle'), findsNothing);
        expect(find.text('Collab değerlendirmelerini gör'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final target in _ProfileTap.values) {
    testWidgets('${target.name} does not push twice before the next frame', (
      tester,
    ) async {
      final actor = _actor(CollabProfileKind.musician);
      final openedRoutes = <RouteSettings>[];
      await _pumpDetail(tester, actor, openedRoutes);
      final targetFinder = _profileTapFinder(target, actor);
      await _revealProfileTarget(tester, target, targetFinder);

      final linkKey = switch (target) {
        _ProfileTap.heroAvatar || _ProfileTap.heroName => _heroKey,
        _ProfileTap.ownerAvatar => _ownerAvatarKey,
        _ProfileTap.ownerName => _ownerNameKey,
      };
      final onTap = tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(linkKey),
              matching: find.byType(InkWell),
            ),
          )
          .onTap!;
      // Invoke the live action twice: a real second pointer is absorbed by
      // Navigator's transition overlay and would not exercise this guard.
      onTap();
      onTap();
      await tester.pumpAndSettle();

      expect(openedRoutes, hasLength(1));
      _expectPublisherRoute(openedRoutes.single, actor);
      expect(tester.takeException(), isNull);
    });
  }

  for (final target in _ProfileTap.values) {
    testWidgets('${target.name} does not navigate with a blank profile ID', (
      tester,
    ) async {
      final actor = _actor(CollabProfileKind.musician, sourceProfileId: ' ');
      final openedRoutes = <RouteSettings>[];
      await _pumpDetail(tester, actor, openedRoutes);
      final targetFinder = _profileTapFinder(target, actor);
      await _revealProfileTarget(tester, target, targetFinder);

      await tester.tap(targetFinder);
      await tester.pumpAndSettle();

      expect(openedRoutes, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final menuTarget in <String>['rating', 'completed jobs', 'chevron']) {
    testWidgets('owner $menuTarget preserves profile and reviews menu', (
      tester,
    ) async {
      final actor = _actor(CollabProfileKind.venue);
      final openedRoutes = <RouteSettings>[];
      await _pumpDetail(tester, actor, openedRoutes);
      final owner = find.byKey(_ownerCardKey);
      await _revealOwner(tester);
      final target = switch (menuTarget) {
        'rating' => find.descendant(
          of: owner,
          matching: find.text('4.8 / 5 · 42 değerlendirme'),
        ),
        'completed jobs' => find.descendant(
          of: owner,
          matching: find.text('128'),
        ),
        _ => find.descendant(
          of: owner,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
      };

      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(openedRoutes, isEmpty);
      expect(find.text('Profili görüntüle'), findsOneWidget);
      expect(find.text('Collab değerlendirmelerini gör'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('owner name semantics action opens profile, not owner menu', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final actor = _actor(CollabProfileKind.musician);
      final openedRoutes = <RouteSettings>[];
      await _pumpDetail(tester, actor, openedRoutes);
      await _revealOwner(tester);
      final node = tester.getSemantics(find.byKey(_ownerNameKey));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(node.label, '${actor.displayName} profilini aç');

      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();

      expect(openedRoutes, hasLength(1));
      _expectPublisherRoute(openedRoutes.single, actor);
      expect(find.text('Profili görüntüle'), findsNothing);
      expect(find.text('Collab değerlendirmelerini gör'), findsNothing);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('identity links remain usable at 320 pixels and 200% text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final actor = _actor(CollabProfileKind.musician);
    final openedRoutes = <RouteSettings>[];
    await _pumpDetail(tester, actor, openedRoutes, textScale: 2);

    final hero = find.byKey(_heroKey);
    expect(tester.getSize(hero).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
    final layoutErrors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      layoutErrors.add(details);
      previousErrorHandler?.call(details);
    };
    try {
      await _revealOwner(tester);
    } finally {
      FlutterError.onError = previousErrorHandler;
    }
    for (final key in <Key>[_ownerAvatarKey, _ownerNameKey]) {
      expect(tester.getSize(find.byKey(key)).height, greaterThanOrEqualTo(44));
    }
    expect(
      tester.takeException(),
      isNull,
      reason: layoutErrors.map((error) => error.toString()).join('\n'),
    );

    await tester.tap(find.byKey(_ownerNameKey));
    await tester.pumpAndSettle();
    expect(openedRoutes, hasLength(1));
    _expectPublisherRoute(openedRoutes.single, actor);
  });
}

enum _ProfileTap { heroAvatar, heroName, ownerAvatar, ownerName }

Future<void> _revealOwner(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(_ownerCardKey),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _revealProfileTarget(
  WidgetTester tester,
  _ProfileTap target,
  Finder targetFinder,
) async {
  if (target == _ProfileTap.ownerAvatar || target == _ProfileTap.ownerName) {
    await _revealOwner(tester);
  }
  await tester.ensureVisible(targetFinder);
  await tester.pumpAndSettle();
}

Finder _profileTapFinder(_ProfileTap target, CollabActor actor) =>
    switch (target) {
      _ProfileTap.heroAvatar => find.descendant(
        of: find.byKey(_heroKey),
        matching: find.byType(CollabIdentityAvatar),
      ),
      _ProfileTap.heroName => find.descendant(
        of: find.byKey(_heroKey),
        matching: find.text(actor.displayName),
      ),
      _ProfileTap.ownerAvatar => find.byKey(_ownerAvatarKey),
      _ProfileTap.ownerName => find.byKey(_ownerNameKey),
    };

Future<void> _pumpDetail(
  WidgetTester tester,
  CollabActor actor,
  List<RouteSettings> openedRoutes, {
  double textScale = 1,
}) async {
  final cubit = CollabListingDetailCubit(
    FakeCollabDetailRepository(listing: collabListingFixture(publisher: actor)),
  );
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      onGenerateRoute: (settings) {
        openedRoutes.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('Profil hedefi')),
        );
      },
      home: CollabListingDetailScreen(
        listingId: 'listing-1',
        detailCubit: cubit,
        showBottomNavigation: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CollabActor _actor(CollabProfileKind kind, {String? sourceProfileId}) =>
    CollabActor(
      actorId: 'actor-${kind.name}',
      profileType: kind,
      sourceProfileId: sourceProfileId ?? '${kind.name}-profile-id',
      contactUserId: '${kind.name}-contact-user-id',
      contactUsername: '${kind.name}_contact',
      displayName: '${kind.name}_publisher',
      rating: 4.8,
      reviewCount: 42,
      completedJobCount: 128,
    );

void _expectPublisherRoute(RouteSettings route, CollabActor actor) {
  final sourceId = actor.sourceProfileId;
  expect(sourceId, isNot(actor.actorId));
  expect(sourceId, isNot(actor.contactUserId));
  switch (actor.profileType) {
    case CollabProfileKind.musician:
      expect(route.name, AppRoutes.musicianPublicProfile);
      expect((route.arguments! as PublicProfileArgs).profileId, sourceId);
    case CollabProfileKind.band:
      expect(route.name, AppRoutes.bandPublicProfile);
      final args = route.arguments! as BandProfileScreenArgs;
      expect(args.bandId, sourceId);
      expect(args.viewMode, BandProfileViewMode.public);
    case CollabProfileKind.venue:
      expect(route.name, AppRoutes.venuePublicProfile);
      expect((route.arguments! as VenuePublicProfileArgs).venueId, sourceId);
    case CollabProfileKind.studio:
      expect(route.name, AppRoutes.studioPublicProfile);
      expect((route.arguments! as PublicProfileArgs).profileId, sourceId);
  }
}
