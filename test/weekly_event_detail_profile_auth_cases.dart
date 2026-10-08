part of 'weekly_event_detail_design_test.dart';

const _profileGateCopy = 'Profilleri görüntülemek için giriş yap veya üye ol.';

void _profileAuthenticationTests(
  _MusicianRepository Function() musicians,
  _BandRepository Function() bands,
  _VenueRepository Function() venues,
) {
  group('event profile authentication', () {
    setUp(() => venues().includePhoto = false);

    for (final kind in ['musician', 'band', 'venue']) {
      for (final registered in [false, true]) {
        testWidgets(
          'guest $kind opens the auth sheet and keeps detail after dismissal (session manager=$registered)',
          (tester) async {
            if (registered) {
              serviceLocator.registerSingleton<AuthSessionManager>(
                _DetailSessionManager(const AuthSession.guest()),
              );
            }
            final routes = <RouteSettings>[];
            await _openDetail(
              tester,
              _profileGateEvent(kind),
              onRoute: routes.add,
            );
            final reads = (
              musicians().requestedIds.length,
              bands().requestedIds.length,
              venues().requestedIds.length,
            );
            final target = _profileGateTarget(kind);
            await tester.ensureVisible(target);
            await tester.tap(target);
            await tester.pumpAndSettle();

            _expectProfileAuthSheet();
            expect(routes, isEmpty);
            expect(musicians().myReads, 0);
            expect((
              musicians().requestedIds.length,
              bands().requestedIds.length,
              venues().requestedIds.length,
            ), reads);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
            expect(find.text(_profileGateCopy), findsNothing);
            expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
            expect(routes, isEmpty);
            await tester.tap(target);
            await tester.pumpAndSettle();
            _expectProfileAuthSheet();
            expect(tester.takeException(), isNull);
          },
        );
      }

      testWidgets('captured $kind tap rechecks logout before navigating', (
        tester,
      ) async {
        final sessions = _registerCommentMember();
        final routes = <RouteSettings>[];
        await _openDetail(tester, _profileGateEvent(kind), onRoute: routes.add);
        final chip = _profileGateTarget(kind);
        await tester.ensureVisible(chip);
        final open = tester
            .widget<InkWell>(
              find.descendant(of: chip, matching: find.byType(InkWell)).first,
            )
            .onTap!;
        sessions.setWithoutNotification(const AuthSession.guest());
        open();
        await tester.pumpAndSettle();

        _expectProfileAuthSheet();
        expect(routes, isEmpty);
        expect(musicians().myReads, 0);
        expect(tester.takeException(), isNull);
      });
    }

    for (final (label, route) in [
      ('Giriş yap', AppRoutes.login),
      ('Üye ol', AppRoutes.register),
    ]) {
      testWidgets(
        'profile auth $label opens its route and returns to the event',
        (tester) async {
          final routes = <RouteSettings>[];
          await _openDetail(
            tester,
            _profileGateEvent('musician'),
            onRoute: routes.add,
          );
          await tester.ensureVisible(_profileGateTarget('musician'));
          await tester.tap(_profileGateTarget('musician'));
          await tester.pumpAndSettle();
          _expectProfileAuthSheet();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();

          expect(routes.map((settings) => settings.name), [route]);
          expect(find.text(_profileGateCopy), findsNothing);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
          expect(find.text(_profileGateCopy), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('profile auth sheet fits 320px at double text scale', (
      tester,
    ) async {
      await _openDetail(
        tester,
        _profileGateEvent('venue'),
        size: const Size(320, 844),
        textScale: 2,
      );
      await tester.ensureVisible(_profileGateTarget('venue'));
      await tester.tap(_profileGateTarget('venue'));
      await tester.pumpAndSettle();
      _expectProfileAuthSheet();
      await tester.ensureVisible(find.text('Üye ol'));
      expect(tester.takeException(), isNull);
    });
  });
}

WeeklyCalendarEvent _profileGateEvent(String kind) => switch (kind) {
  'musician' => _event(
    performerType: 'MUSICIAN',
    artistProfileId: 'musician-approved',
  ),
  'band' => _event(performerType: 'BAND', bandProfileId: 'band-approved'),
  _ => _event(venueId: 'venue-real-id'),
};

Finder _profileGateTarget(String kind) => find.byKey(
  Key(
    kind == 'venue'
        ? 'event-venue-profile-chip'
        : 'event-performer-profile-chip',
  ),
);

void _expectProfileAuthSheet() {
  expect(find.text('Profiller'), findsOneWidget);
  expect(find.text(_profileGateCopy), findsOneWidget);
  expect(find.text('Giriş yap'), findsOneWidget);
  expect(find.text('Üye ol'), findsOneWidget);
  expect(find.byType(BottomSheet), findsOneWidget);
}
