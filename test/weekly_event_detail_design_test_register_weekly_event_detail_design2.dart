part of 'weekly_event_detail_design_test.dart';

extension _RegisterWeeklyEventDetailDesign2 on _WeeklyEventDetailDesignCases {
  void _registerWeeklyEventDetailDesign2() {
    testWidgets('a late detail response is ignored after closing the screen', (
      tester,
    ) async {
      details.completion = Completer<Result<VenueEventDetail>>();
      await _openDetail(tester, _event());
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      details.completion!.complete(
        Result.success(_detail(description: 'Geç gelen açıklama')),
      );
      await tester.pumpAndSettle();

      expect(comments.listCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'unapproved MANUAL identity never exposes a leaked profile id',
      (tester) async {
        final routes = <RouteSettings>[];
        await _openDetail(
          tester,
          _event(
            artistProfileId: 'unapproved-musician',
            performerType: 'MANUAL',
          ),
          onRoute: routes.add,
        );

        final chip = find.byKey(const Key('event-performer-profile-chip'));
        expect(chip, findsOneWidget);
        expect(find.text('@bugrasahin'), findsNothing);
        expect(find.text('bugrasahin'), findsOneWidget);
        expect(_performerNameInkWell(tester, 'bugrasahin').onTap, isNull);
        expect(_performerInfoButton(), findsOneWidget);
        expect(musicians.requestedIds, isEmpty);
        expect(bands.requestedIds, isEmpty);
        await tester.ensureVisible(chip);
        await tester.tap(find.text('bugrasahin'));
        await tester.pumpAndSettle();
        expect(routes, isEmpty);
        expect(_performerInfoDialog(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'pending band exposes only a separate participation info action',
      (tester) async {
        final routes = <RouteSettings>[];
        await _openDetail(
          tester,
          _event(artistName: 'Şahbaz', performerType: 'BAND'),
          onRoute: routes.add,
        );

        expect(find.text('Şahbaz'), findsOneWidget);
        expect(find.text('@Şahbaz'), findsNothing);
        expect(_performerNameInkWell(tester, 'Şahbaz').onTap, isNull);
        expect(find.byTooltip('Katılım bilgisi'), findsOneWidget);
        await tester.tap(find.text('Şahbaz'));
        await tester.pumpAndSettle();
        expect(_performerInfoDialog(), findsNothing);

        await tester.tap(_performerInfoButton());
        await tester.pumpAndSettle();
        expect(_performerInfoDialog(), findsOneWidget);
        expect(find.text('Katılım bilgisi'), findsOneWidget);
        expect(
          find.text('Sanatçı/grup bu etkinliğe katılımını henüz doğrulamadı.'),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: _performerInfoDialog(),
            matching: find.text('Şahbaz'),
          ),
          findsNothing,
        );
        expect(routes, isEmpty);
        expect(musicians.requestedIds, isEmpty);
        expect(bands.requestedIds, isEmpty);

        await tester.tap(find.text('Anladım'));
        await tester.pumpAndSettle();
        expect(_performerInfoDialog(), findsNothing);
        expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('malformed dual profile ids fail closed in the identity chip', (
      tester,
    ) async {
      final routes = <RouteSettings>[];
      await _openDetail(
        tester,
        _event(
          artistName: 'Şahbaz',
          performerType: 'BAND',
          artistProfileId: 'legacy-musician',
          bandProfileId: 'legacy-band',
        ),
        onRoute: routes.add,
      );

      expect(find.text('@Şahbaz'), findsNothing);
      expect(_performerNameInkWell(tester, 'Şahbaz').onTap, isNull);
      expect(_performerInfoButton(), findsOneWidget);
      await tester.tap(find.text('Şahbaz'));
      await tester.pumpAndSettle();
      expect(routes, isEmpty);
      expect(musicians.requestedIds, isEmpty);
      expect(bands.requestedIds, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pending incoming handles lose every leading at sign', (
      tester,
    ) async {
      await _openDetail(tester, _event(artistName: '  @@bugrasahin  '));

      expect(find.text('bugrasahin'), findsOneWidget);
      expect(find.textContaining('@bugrasahin'), findsNothing);
      await tester.tap(_performerInfoButton());
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: _performerInfoDialog(),
          matching: find.text('bugrasahin'),
        ),
        findsNothing,
      );
      expect(find.textContaining('@bugrasahin'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final placeholder in [
      '',
      '  ',
      '-',
      'Yakinda aciklanacak',
      'Yakında açıklanacak',
      'Belirtilmemiş',
      'Belirtilmemis',
      'Performer',
      '@@',
    ]) {
      testWidgets(
        'placeholder "$placeholder" does not imply a pending artist',
        (tester) async {
          await _openDetail(tester, _event(artistName: placeholder));

          expect(_performerInfoButton(), findsNothing);
          final placeholderRow = find.descendant(
            of: find.byKey(const Key('event-performer-profile-chip')),
            matching: find.byType(Row),
          );
          expect(
            tester.widget<Row>(placeholderRow).mainAxisAlignment,
            MainAxisAlignment.center,
          );
          final chipText = tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byKey(const Key('event-performer-profile-chip')),
                  matching: find.byType(Text),
                ),
              )
              .map((widget) => widget.data ?? '');
          expect(chipText.any((text) => text.contains('@')), isFalse);
          expect(musicians.requestedIds, isEmpty);
          expect(bands.requestedIds, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('participation info cannot stack dialogs on repeated presses', (
      tester,
    ) async {
      await _openDetail(tester, _event());
      final openInfo = tester
          .widget<IconButton>(_performerInfoButton())
          .onPressed!;

      openInfo();
      openInfo();
      await tester.pumpAndSettle();
      expect(_performerInfoDialog(), findsOneWidget);
      expect(
        find.byKey(
          const Key('event-performer-verification-dialog'),
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
      expect(_performerInfoDialog(), findsNothing);
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);

      await tester.tap(_performerInfoButton());
      await tester.pumpAndSettle();
      expect(_performerInfoDialog(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'stale info dismissal cannot close another route or pop twice',
      (tester) async {
        await _openDetail(tester, _event());
        await tester.tap(_performerInfoButton());
        await tester.pumpAndSettle();
        final dismiss = tester
            .widget<GradientOutlineButton>(
              find.byKey(const Key('event-performer-verification-dismiss')),
            )
            .onPressed!;
        final navigator = Navigator.of(tester.element(_performerInfoDialog()));

        unawaited(
          navigator.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Covering info route')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        dismiss();
        await tester.pumpAndSettle();
        expect(find.text('Covering info route'), findsOneWidget);

        navigator.pop();
        await tester.pumpAndSettle();
        expect(_performerInfoDialog(), findsOneWidget);
        dismiss();
        dismiss();
        await tester.pumpAndSettle();
        expect(_performerInfoDialog(), findsNothing);
        expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('stale participation info opener respects the current route', (
      tester,
    ) async {
      await _openDetail(tester, _event());
      final openInfo = tester
          .widget<IconButton>(_performerInfoButton())
          .onPressed!;
      final navigator = Navigator.of(tester.element(_performerInfoButton()));

      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covering route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      openInfo();
      await tester.pumpAndSettle();
      expect(find.text('Covering route'), findsOneWidget);
      expect(_performerInfoDialog(), findsNothing);

      navigator.pop();
      await tester.pumpAndSettle();
      openInfo();
      await tester.pumpAndSettle();
      expect(_performerInfoDialog(), findsOneWidget);
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();
      openInfo();
      await tester.pumpAndSettle();
      expect(_performerInfoDialog(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'participation info remains usable at 320 dp and doubled text',
      (tester) async {
        const name = 'Çok Uzun Sanatçı Adı ve Bütün Müzisyen Arkadaşları';
        await _openDetail(
          tester,
          _event(artistName: name),
          size: const Size(320, 740),
          textScale: 2,
        );

        expect(_performerNameInkWell(tester, name).onTap, isNull);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(_performerInfoButton());
        await tester.tap(_performerInfoButton());
        await tester.pumpAndSettle();
        expect(_performerInfoDialog(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Anladım'));
        await tester.tap(find.text('Anladım'));
        await tester.pumpAndSettle();
        expect(_performerInfoDialog(), findsNothing);
        expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('accepted musician retains its explicit public profile route', (
      tester,
    ) async {
      _registerCommentMember();
      RouteSettings? destination;
      await _openDetail(
        tester,
        _event(
          artistName: '  @@bugrasahin  ',
          artistProfileId: 'musician-approved',
          performerType: 'MUSICIAN',
        ),
        onRoute: (settings) => destination = settings,
      );

      expect(find.text('@bugrasahin'), findsOneWidget);
      expect(find.text('@@bugrasahin'), findsNothing);
      expect(_performerInfoButton(), findsNothing);
      final chip = find.byKey(const Key('event-performer-profile-chip'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(destination?.name, AppRoutes.musicianPublicProfile);
      expect(
        (destination?.arguments as PublicProfileArgs).profileId,
        'musician-approved',
      );
      expect(musicians.requestedIds, ['musician-approved']);
      expect(bands.requestedIds, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'accepted band retains the band route without musician lookup',
      (tester) async {
        _registerCommentMember();
        RouteSettings? destination;
        await _openDetail(
          tester,
          _event(
            artistName: '@Şahbaz',
            bandProfileId: 'band-approved',
            performerType: 'BAND',
          ),
          onRoute: (settings) => destination = settings,
        );

        expect(find.text('@Şahbaz'), findsOneWidget);
        expect(find.text('@@Şahbaz'), findsNothing);
        expect(_performerInfoButton(), findsNothing);
        final chip = find.byKey(const Key('event-performer-profile-chip'));
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();

        expect(destination?.name, AppRoutes.bandPublicProfile);
        final args = destination?.arguments as BandProfileScreenArgs;
        expect(args.bandId, 'band-approved');
        expect(args.viewMode, BandProfileViewMode.public);
        expect(bands.requestedIds, ['band-approved']);
        expect(musicians.requestedIds, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('fallback poster opens in a zoomable dismissible full screen', (
      tester,
    ) async {
      await _openDetail(tester, _event());
      await tester.tap(_posterTapTarget());
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      final fullScreenPoster = find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byType(EventPosterFallback),
      );
      expect(fullScreenPoster, findsOneWidget);
      expect(
        tester.widget<EventPosterFallback>(fullScreenPoster).showDetails,
        isTrue,
      );
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'comment input sends one trimmed comment for the current event',
      (tester) async {
        _registerCommentMember();
        await _openDetail(tester, _event());
        await tester.enterText(
          find.byType(TextField),
          '  Bilet gerekiyor mu?  ',
        );
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pumpAndSettle();

        expect(comments.creations, [
          ('EVENT', 'event-design-1', 'Bilet gerekiyor mu?'),
        ]);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
        expect(comments.comments.single.text, 'Bilet gerekiyor mu?');
        expect(tester.takeException(), isNull);
      },
    );

    _commentAccessPreviewTests(() => comments);

    _detailReferenceTests(() => comments);
  }
}
