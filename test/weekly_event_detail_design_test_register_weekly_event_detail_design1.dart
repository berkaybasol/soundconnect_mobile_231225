part of 'weekly_event_detail_design_test.dart';

extension _RegisterWeeklyEventDetailDesign1 on _WeeklyEventDetailDesignCases {
  void _registerWeeklyEventDetailDesign1() {
    setUp(() async {
      await serviceLocator.reset();
      details = _DetailRepository();
      comments = _CommentsRepository();
      musicians = _MusicianRepository();
      bands = _BandRepository();
      venues = _VenueRepository();
      serviceLocator
        ..registerSingleton<VenueEventRepository>(details)
        ..registerSingleton<EngagementRepository>(comments)
        ..registerSingleton<MusicianProfileRepository>(musicians)
        ..registerSingleton<BandRepository>(bands)
        ..registerSingleton<VenueProfileRepository>(venues);
    });

    tearDown(serviceLocator.reset);

    _selfProfileNavigationTests(() => musicians);

    _bandProfileNavigationTests(() => bands);

    _adaptiveProfileChipTests(() => venues);

    _profileAuthenticationTests(() => musicians, () => bands, () => venues);

    _commentAuthenticationTests(() => comments);

    _commentQualityTests(() => comments);

    _replyDesignTests(() => comments);

    _replyPaginationTests(() => comments);

    _detailAnalyticsTests(() => details, () => venues);

    _detailAudienceTests(() => venues);

    _detailLoadingTests();

    testWidgets(
      'restored detail keeps its hero and chips without time seconds',
      (tester) async {
        await _openDetail(tester, _event());

        expect(find.textContaining('06.09.2026'), findsNWidgets(2));
        expect(find.textContaining('20:00'), findsNWidgets(2));
        expect(find.textContaining('22:00'), findsNWidgets(2));
        expect(find.textContaining('20:00:00'), findsNothing);
        expect(find.textContaining('22:00:00'), findsNothing);
        final shareButton = find.widgetWithText(TextButton, 'Paylaş');
        expect(shareButton, findsOneWidget);
        expect(tester.getSize(shareButton).width, greaterThanOrEqualTo(350));
        expect(find.byTooltip('Paylaş'), findsNothing);
        expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);
        expect(_posterTapTarget(), findsOneWidget);
        expect(find.byType(EventPosterFallback), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('share uses the exact management panel gradient outline', (
      tester,
    ) async {
      await _openDetail(tester, _event());

      final buttonFinder = find.widgetWithText(TextButton, 'Paylaş');
      final button = tester.widget<TextButton>(buttonFinder);
      final style = button.style!;
      expect(
        find.byKey(const Key('event-share-action-button')),
        findsOneWidget,
      );
      expect(style.foregroundColor!.resolve({}), AppColors.white);
      expect(style.backgroundColor!.resolve({}), Colors.transparent);
      expect(
        style.padding!.resolve({}),
        const EdgeInsets.symmetric(vertical: 14),
      );
      expect(
        (style.shape!.resolve({})! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(18),
      );

      final outline = find.ancestor(
        of: buttonFinder,
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox || widget.decoration is! BoxDecoration) {
            return false;
          }
          return (widget.decoration as BoxDecoration).gradient != null;
        }),
      );
      expect(outline, findsOneWidget);
      final box = tester.widget<DecoratedBox>(outline);
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(18));
      expect(
        decoration.gradient,
        LinearGradient(colors: AppColors.brandGradient),
      );
      expect((box.child! as Padding).padding, const EdgeInsets.all(0.7));

      final clip = find
          .ancestor(of: buttonFinder, matching: find.byType(ClipRRect))
          .first;
      expect(
        tester.widget<ClipRRect>(clip).borderRadius,
        BorderRadius.circular(18),
      );
      final innerSurface = tester.widget<Container>(
        find.ancestor(of: buttonFinder, matching: find.byType(Container)).first,
      );
      expect(
        innerSurface.color,
        Theme.of(
          tester.element(buttonFinder),
        ).colorScheme.surfaceContainerHighest,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'image share stays single flight and disabled through preparation and sending',
      (tester) async {
        details.result = Result.success(_shareDetail());
        final service = _EventShareService()
          ..preparation = Completer<PreparedEventShare>()
          ..sending = Completer<void>();
        await _openDetail(tester, _event(), shareService: service);
        final shareButton = find.widgetWithText(TextButton, 'Paylaş');
        final originalSize = tester.getSize(shareButton);
        final share = tester.widget<TextButton>(shareButton).onPressed!;

        share();
        share();
        await tester.pump();
        expect(
          details.requestedIds,
          hasLength(2),
        ); // Initial load + fresh export.
        expect(service.preparedData, hasLength(1));
        expect(service.shared, isEmpty);
        expect(tester.widget<TextButton>(shareButton).onPressed, isNull);
        expect(
          find.descendant(
            of: shareButton,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(shareButton), originalSize);

        final prepared = _prepared(service.preparedData.single);
        service.preparation!.complete(prepared);
        await _pumpShareSheet(tester);
        expect(find.byKey(const Key('event-share-sheet')), findsOneWidget);
        expect(service.shared, isEmpty);
        final preview = tester.widget<Image>(
          find.byKey(const Key('event-share-preview')),
        );
        expect((preview.image as MemoryImage).bytes, same(prepared.bytes));

        final target = tester
            .widget<InkWell>(find.byKey(const Key('event-share-target-other')))
            .onTap!;
        target();
        target(); // A queued second tap must not pop the detail or send twice.
        await _pumpShareSheet(tester);
        expect(service.shared, hasLength(1));
        expect(service.shared.single.$1, same(prepared));
        expect(service.shared.single.$2, EventShareTarget.other);
        expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
        expect(tester.widget<TextButton>(shareButton).onPressed, isNull);
        expect(tester.getSize(shareButton), originalSize);

        service.sending!.complete();
        await tester.pumpAndSettle();
        expect(tester.widget<TextButton>(shareButton).onPressed, isNotNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(service.shared, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );

    for (final freshLinked in [false, true]) {
      testWidgets(
        'share uses fresh public consent, not ${freshLinked ? 'unlinked' : 'linked'} route data',
        (tester) async {
          final service = _EventShareService();
          await _openDetail(
            tester,
            _event(
              performerType: freshLinked ? 'MANUAL' : 'MUSICIAN',
              artistProfileId: freshLinked ? null : 'stale-profile-id',
              artistName: 'Eski sanatçı',
            ),
            shareService: service,
          );
          details.result = Result.success(_shareDetail(linked: freshLinked));

          await tester.tap(find.widgetWithText(TextButton, 'Paylaş'));
          await _pumpShareSheet(tester);

          expect(details.requestedIds, ['event-design-1', 'event-design-1']);
          final data = service.preparedData.single;
          expect(data.title, 'Güncel etkinlik');
          expect(data.performerName, 'Yeni sanatçı');
          expect(data.performerLinked, freshLinked);
          expect(
            data.description,
            'Mekânın etkinlik için yazdığı güncel açıklama.',
          );
          expect(
            data.performerLabel,
            freshLinked ? '@Yeni sanatçı' : 'Yeni sanatçı',
          );
          expect(data.eventDate, DateTime(2026, 9, 12));
          expect(data.timeLabel, '21:30 – 23:00');
          expect(data.venueName, 'yenimekan');
          expect(data.location, 'Kadıköy · İstanbul');
          expect(data.posterUrl, 'https://example.invalid/new-poster.png');
          expect(
            data.shareUrl,
            'https://soundconnect.app/event/event-design-1',
          );
          expect(service.shared, isEmpty);

          await tester.tap(find.byTooltip('Kapat'));
          await tester.pumpAndSettle();
          expect(service.shared, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final description in [null, '', '   ']) {
      testWidgets(
        'share never substitutes stale copy for fresh description "$description"',
        (tester) async {
          final service = _EventShareService();
          await _openDetail(
            tester,
            _event(description: 'Eski etkinlik açıklaması'),
            shareService: service,
          );
          details.result = Result.success(
            _shareDetail(description: description),
          );
          await tester.tap(find.widgetWithText(TextButton, 'Paylaş'));
          await _pumpShareSheet(tester);
          expect(service.preparedData.single.description, isEmpty);
          expect(
            service.preparedData.single.accessibilityDescription,
            isNot(contains('Eski etkinlik açıklaması')),
          );
          await tester.tap(find.byTooltip('Kapat'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final target in EventShareTarget.values) {
      testWidgets('image is sent only after selecting ${target.name}', (
        tester,
      ) async {
        final originalPlatform = debugDefaultTargetPlatformOverride;
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          details.result = Result.success(_shareDetail());
          final service = _EventShareService();
          await _openDetail(tester, _event(), shareService: service);

          await tester.tap(find.widgetWithText(TextButton, 'Paylaş'));
          await _pumpShareSheet(tester);
          expect(service.shared, isEmpty);
          final preview = tester.widget<Image>(
            find.byKey(const Key('event-share-preview')),
          );
          final previewBytes = (preview.image as MemoryImage).bytes;
          await tester.tap(
            find.byKey(Key('event-share-target-${target.name}')),
          );
          await tester.pumpAndSettle();

          expect(service.shared, hasLength(1));
          expect(service.shared.single.$1.bytes, same(previewBytes));
          expect(service.shared.single.$2, target);
          expect(find.byKey(const Key('event-share-sheet')), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          debugDefaultTargetPlatformOverride = originalPlatform;
        }
      });
    }

    testWidgets('closing the image preview never opens an external share', (
      tester,
    ) async {
      details.result = Result.success(_shareDetail());
      final service = _EventShareService();
      await _openDetail(tester, _event(), shareService: service);
      await tester.tap(find.widgetWithText(TextButton, 'Paylaş'));
      await _pumpShareSheet(tester);
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();

      expect(service.preparedData, hasLength(1));
      expect(service.shared, isEmpty);
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Paylaş'))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    });

    for (final leaveMode in ['covered route', 'disposed screen']) {
      testWidgets(
        'finishing preparation after $leaveMode has no late UI or send',
        (tester) async {
          details.result = Result.success(_shareDetail());
          final service = _EventShareService()
            ..preparation = Completer<PreparedEventShare>();
          await _openDetail(tester, _event(), shareService: service);
          await tester.tap(find.widgetWithText(TextButton, 'Paylaş'));
          await tester.pump();
          expect(service.preparedData, hasLength(1));

          if (leaveMode == 'covered route') {
            Navigator.of(
              tester.element(find.byType(WeeklyEventDetailScreen)),
            ).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Başka sayfa')),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          } else {
            await tester.pumpWidget(const MaterialApp(home: Text('Ayrıldık')));
          }
          service.preparation!.complete(_prepared(service.preparedData.single));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('event-share-sheet')), findsNothing);
          expect(
            find.byKey(const Key('event-share-sheet'), skipOffstage: false),
            findsNothing,
          );
          expect(service.shared, isEmpty);
          expect(
            find.text('Paylaşım hazırlanamadı. Lütfen tekrar dene.'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final unavailable in ['failed', 'mismatched', 'blank id']) {
      testWidgets(
        '$unavailable fresh detail prevents export and permits retry',
        (tester) async {
          final service = _EventShareService();
          await _openDetail(tester, _event(), shareService: service);
          if (unavailable != 'failed') {
            details.result = Result.success(
              _shareDetail(
                id: unavailable == 'mismatched' ? 'someone-elses-event' : ' ',
              ),
            );
          }
          await tester.tap(find.widgetWithText(TextButton, 'Paylaş'));
          await tester.pumpAndSettle();

          expect(service.preparedData, isEmpty);
          expect(service.shared, isEmpty);
          expect(find.byKey(const Key('event-share-sheet')), findsNothing);
          expect(
            find.text('Paylaşım hazırlanamadı. Lütfen tekrar dene.'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<TextButton>(find.widgetWithText(TextButton, 'Paylaş'))
                .onPressed,
            isNotNull,
          );

          details.result = Result.success(_shareDetail());
          await tester.tap(find.widgetWithText(TextButton, 'Paylaş'));
          await _pumpShareSheet(tester);
          expect(service.preparedData, hasLength(1));
          expect(find.byKey(const Key('event-share-sheet')), findsOneWidget);
          await tester.tap(find.byTooltip('Kapat'));
          await tester.pumpAndSettle();
          expect(service.shared, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final failStage in ['preparation', 'sending']) {
      testWidgets('$failStage errors recover the share button', (tester) async {
        details.result = Result.success(_shareDetail());
        final service = _EventShareService()
          ..failPreparation = failStage == 'preparation'
          ..failSending = failStage == 'sending';
        await _openDetail(tester, _event(), shareService: service);
        await tester.tap(find.widgetWithText(TextButton, 'Paylaş'));
        if (failStage == 'sending') {
          await _pumpShareSheet(tester);
          await tester.tap(find.byKey(const Key('event-share-target-other')));
        }
        await tester.pumpAndSettle();

        expect(
          find.text('Paylaşım hazırlanamadı. Lütfen tekrar dene.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Paylaş'))
              .onPressed,
          isNotNull,
        );
        expect(find.byKey(const Key('event-share-sheet')), findsNothing);
        expect(service.preparedData, hasLength(1));
        expect(service.shared, hasLength(failStage == 'sending' ? 1 : 0));
        expect(tester.takeException(), isNull);
      });
    }

    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        for (final identity in [
          (name: 'pending musician', type: 'MUSICIAN', approved: false),
          (name: 'pending band', type: 'BAND', approved: false),
          (name: 'approved musician', type: 'MUSICIAN', approved: true),
          (name: 'approved band', type: 'BAND', approved: true),
        ]) {
          testWidgets(
            '${identity.name} and venue remain on one row at $width dp / ${scale}x',
            (tester) async {
              const performerName =
                  'Çok Uzun Sanatçı ve Grup Adı ile Konuk Müzisyenler';
              const venueName = 'soundconnectankarauzunmekankullaniciadi';
              await _openDetail(
                tester,
                _event(
                  artistName: performerName,
                  performerType: identity.type,
                  artistProfileId:
                      identity.approved && identity.type == 'MUSICIAN'
                      ? 'musician-approved'
                      : null,
                  bandProfileId: identity.approved && identity.type == 'BAND'
                      ? 'band-approved'
                      : null,
                  venueName: venueName,
                  venueId: 'venue-real-id',
                ),
                size: Size(width, 844),
                textScale: scale,
                settle: false,
              );

              final performer = find.byKey(
                const Key('event-performer-profile-chip'),
              );
              final venue = find.byKey(const Key('event-venue-profile-chip'));
              expect(performer, findsOneWidget);
              expect(venue, findsOneWidget);
              final performerBounds = tester.getRect(performer);
              final venueBounds = tester.getRect(venue);
              expect(performerBounds.top, closeTo(venueBounds.top, 0.01));
              expect(performerBounds.bottom, closeTo(venueBounds.bottom, 0.01));
              expect(performerBounds.height, greaterThanOrEqualTo(48));
              expect(performerBounds.right, lessThan(venueBounds.left));
              expect(performerBounds.left, greaterThanOrEqualTo(0));
              expect(venueBounds.right, lessThanOrEqualTo(width));
              expect(venues.requestedIds, ['venue-real-id']);
              final avatar = tester.widget<AppCachedNetworkImage>(
                find.descendant(
                  of: venue,
                  matching: find.byType(AppCachedNetworkImage),
                ),
              );
              expect(avatar.imageUrl, 'https://example.invalid/venue.jpg');
              expect(avatar.width, 20);
              expect(avatar.height, 20);

              final displayedPerformer = identity.approved
                  ? '@$performerName'
                  : performerName;
              for (final label in [displayedPerformer, '@$venueName']) {
                final text = tester.widget<Text>(find.text(label));
                expect(text.maxLines, 1);
                expect(text.overflow, TextOverflow.ellipsis);
                expect(find.byTooltip(label), findsOneWidget);
              }
              expect(
                _performerNameInkWell(tester, displayedPerformer).onTap,
                identity.approved ? isNotNull : isNull,
              );
              expect(
                _performerInfoButton(),
                identity.approved ? findsNothing : findsOneWidget,
              );
              final venueLink = tester.widget<InkWell>(
                find
                    .ancestor(
                      of: find.descendant(
                        of: venue,
                        matching: find.text('@$venueName'),
                      ),
                      matching: find.byType(InkWell),
                    )
                    .first,
              );
              expect(venueLink.onTap, isNotNull);
              expect(
                tester.getTopLeft(find.text('06.09.2026')).dy,
                greaterThan(performerBounds.bottom),
              );
              expect(find.text('20:00 - 22:00'), findsOneWidget);
              expect(find.text('Ankara / Çankaya / Çayyolu'), findsOneWidget);
              expect(tester.takeException(), isNull);

              // This matrix covers the real avatar's 20 dp loading branch, not
              // external disk/network work. Remove it before settling so its
              // indeterminate progress indicator cannot keep the test alive.
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
              expect(tester.binding.transientCallbackCount, 0);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets(
      'missing venue and location never expose placeholder separators',
      (tester) async {
        await _openDetail(
          tester,
          _event(venueName: ' ', city: '', district: '-', neighborhood: '  '),
        );

        final displayedText = tester
            .widgetList<Text>(find.byType(Text))
            .map(
              (widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '',
            );
        expect(displayedText.where((text) => text.trim() == '@'), isEmpty);
        expect(displayedText.where((text) => text.contains(' / ')), isEmpty);
        expect(displayedText.where((text) => text.trim() == '-'), isEmpty);
        expect(find.textContaining('MANUAL performansı'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('320 dp with doubled text and long identity stays usable', (
      tester,
    ) async {
      _registerCommentMember();
      await _openDetail(
        tester,
        _event(
          title:
              'SoundConnect Sonbahar Akustik Gecesi ve Çok Uzun Bir Etkinlik Başlığı',
          artistName: 'Çok Uzun Sanatçı Adı ve Bütün Müzisyen Arkadaşları',
          venueName: 'soundconnectankarauzunmekankullaniciadi',
          city: 'Çok Uzun Şehir İsmi',
          district: 'Çok Uzun İlçe İsmi',
          neighborhood: 'Çok Uzun Mahalle İsmi',
          description: 'Konuk sanatçılarla birlikte akustik bir gece.',
        ),
        size: const Size(320, 740),
        textScale: 2,
      );

      expect(find.widgetWithText(TextButton, 'Paylaş'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -640));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'Sahne kaçta başlıyor?');
      expect(find.text('Sahne kaçta başlıyor?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'reused detail reloads context and clears the previous event description',
      (tester) async {
        details.result = Result.success(
          _detail(description: 'İlk etkinliğin sunucu açıklaması'),
        );
        await _openDetail(tester, _event());
        expect(find.text('İlk etkinliğin sunucu açıklaması'), findsOneWidget);
        final pending = Completer<Result<VenueEventDetail>>();
        details.completion = pending;
        await _openDetail(
          tester,
          _event(id: 'event-2', description: 'İkinci etkinliğin özeti'),
        );
        expect(find.text('İlk etkinliğin sunucu açıklaması'), findsNothing);
        expect(find.text('İkinci etkinliğin özeti'), findsOneWidget);
        expect(details.requestedIds, ['event-design-1', 'event-2']);
        pending.complete(
          Result.success(
            _shareDetail(
              id: 'event-2',
              description: 'İkinci etkinliğin sunucu açıklaması',
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('İkinci etkinliğin sunucu açıklaması'),
          findsOneWidget,
        );
        expect(find.text('İkinci etkinliğin özeti'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reused detail ignores the previous event late context response',
      (tester) async {
        final previous = Completer<Result<VenueEventDetail>>();
        details.completion = previous;
        await _openDetail(tester, _event());
        details.completion = null;
        details.result = Result.success(
          _shareDetail(
            id: 'event-2',
            description: 'Güncel etkinlik açıklaması',
          ),
        );
        await _openDetail(tester, _event(id: 'event-2'));
        previous.complete(
          Result.success(_detail(description: 'Geciken eski açıklama')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Güncel etkinlik açıklaması'), findsOneWidget);
        expect(find.text('Geciken eski açıklama'), findsNothing);
        expect(details.requestedIds, ['event-design-1', 'event-2']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'same event refreshed metadata reloads its description and ignores older responses',
      (tester) async {
        final previous = Completer<Result<VenueEventDetail>>();
        details.completion = previous;
        await _openDetail(tester, _event(description: 'İlk özet'));
        details.completion = null;
        details.result = Result.success(
          _detail(description: 'Düzenlenmiş sunucu açıklaması'),
        );
        await _openDetail(
          tester,
          _event(title: 'Düzenlenen etkinlik', description: 'İkinci özet'),
        );
        previous.complete(
          Result.success(_detail(description: 'Geciken eski açıklama')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Düzenlenmiş sunucu açıklaması'), findsOneWidget);
        expect(find.text('Geciken eski açıklama'), findsNothing);
        expect(details.requestedIds, ['event-design-1', 'event-design-1']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('nullable fresh description clears a stale summary', (
      tester,
    ) async {
      details.completion = Completer<Result<VenueEventDetail>>();
      await _openDetail(
        tester,
        _event(description: 'Artık geçerli olmayan eski açıklama'),
      );

      details.completion!.complete(Result.success(_detail(description: null)));
      await tester.pumpAndSettle();

      expect(find.text('Artık geçerli olmayan eski açıklama'), findsNothing);
      expect(find.textContaining('MANUAL performansı'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'fresh authored description is displayed even without share URL',
      (tester) async {
        const authored =
            'MANUAL performansı — sanatçının kendi etkinlik açıklaması.';
        details.result = Result.success(_detail(description: authored));
        await _openDetail(tester, _event(description: 'Eski açıklama'));

        await tester.ensureVisible(find.text(authored));
        await tester.pumpAndSettle();
        expect(find.text(authored), findsOneWidget);
        expect(find.text('Eski açıklama'), findsNothing);
        expect(details.requestedIds, ['event-design-1']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'failed detail request preserves the real supplied description',
      (tester) async {
        _registerCommentMember();
        const authored =
            'Kapılar 19.30’da açılır; akustik konser 20.00’de başlar.';
        await _openDetail(tester, _event(description: authored));

        await tester.ensureVisible(find.text(authored));
        await tester.pumpAndSettle();
        expect(find.text(authored), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
