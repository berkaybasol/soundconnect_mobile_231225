import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_public_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_route_args.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_data.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_service.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/event_poster_fallback.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

part 'weekly_event_detail_self_navigation_cases.dart';

void main() {
  late _DetailRepository details;
  late _CommentsRepository comments;
  late _MusicianRepository musicians;
  late _BandRepository bands;
  late _VenueRepository venues;

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

  testWidgets('restored detail keeps its hero and chips without time seconds', (
    tester,
  ) async {
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
  });

  testWidgets('share uses the exact management panel gradient outline', (
    tester,
  ) async {
    await _openDetail(tester, _event());

    final buttonFinder = find.widgetWithText(TextButton, 'Paylaş');
    final button = tester.widget<TextButton>(buttonFinder);
    final style = button.style!;
    expect(find.byKey(const Key('event-share-action-button')), findsOneWidget);
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
        expect(data.shareUrl, 'https://soundconnect.app/event/event-design-1');
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
        details.result = Result.success(_shareDetail(description: description));
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
        await tester.tap(find.byKey(Key('event-share-target-${target.name}')));
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
    testWidgets('$unavailable fresh detail prevents export and permits retry', (
      tester,
    ) async {
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
    });
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
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '');
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

  testWidgets('failed detail request preserves the real supplied description', (
    tester,
  ) async {
    const authored = 'Kapılar 19.30’da açılır; akustik konser 20.00’de başlar.';
    await _openDetail(tester, _event(description: authored));

    await tester.ensureVisible(find.text(authored));
    await tester.pumpAndSettle();
    expect(find.text(authored), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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

    expect(comments.listCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unapproved MANUAL identity never exposes a leaked profile id', (
    tester,
  ) async {
    final routes = <RouteSettings>[];
    await _openDetail(
      tester,
      _event(artistProfileId: 'unapproved-musician', performerType: 'MANUAL'),
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
  });

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
    testWidgets('placeholder "$placeholder" does not imply a pending artist', (
      tester,
    ) async {
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
    });
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

  testWidgets('stale info dismissal cannot close another route or pop twice', (
    tester,
  ) async {
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
  });

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

  testWidgets('participation info remains usable at 320 dp and doubled text', (
    tester,
  ) async {
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
  });

  testWidgets('accepted musician retains its explicit public profile route', (
    tester,
  ) async {
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

  testWidgets('accepted band retains the band route without musician lookup', (
    tester,
  ) async {
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
  });

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

  testWidgets('comment input sends one trimmed comment for the current event', (
    tester,
  ) async {
    await _openDetail(tester, _event());
    await tester.enterText(find.byType(TextField), '  Bilet gerekiyor mu?  ');
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
  });
}

Finder _performerInfoButton() =>
    find.byKey(const Key('event-performer-verification-info'));

Finder _performerInfoDialog() =>
    find.byKey(const Key('event-performer-verification-dialog'));

InkWell _performerNameInkWell(WidgetTester tester, String name) {
  final chip = find.byKey(const Key('event-performer-profile-chip'));
  return tester.widget<InkWell>(
    find
        .ancestor(
          of: find.descendant(of: chip, matching: find.text(name)),
          matching: find.byType(InkWell),
        )
        .first,
  );
}

Finder _posterTapTarget() => find
    .ancestor(
      of: find.byType(EventPosterFallback),
      matching: find.byType(InkWell),
    )
    .first;

Future<void> _openDetail(
  WidgetTester tester,
  WeeklyCalendarEvent event, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  ValueChanged<RouteSettings>? onRoute,
  EventShareService? shareService,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: WeeklyEventDetailScreen(event: event, shareService: shareService),
      onGenerateRoute: (settings) {
        onRoute?.call(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              const Scaffold(body: Text('Public profile destination')),
        );
      },
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // Resolve the fake repositories and render their avatar/identity result
    // without waiting for the network image's indeterminate placeholder.
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump();
    }
  }
}

WeeklyCalendarEvent _event({
  String title = 'M-T1 — Katıl, gösterme',
  String artistName = 'bugrasahin',
  String? artistProfileId,
  String? bandProfileId,
  String performerType = 'MANUAL',
  String venueName = 'soundconnectankara',
  String? venueId,
  String city = 'Ankara',
  String district = 'Çankaya',
  String neighborhood = 'Çayyolu',
  String description = '',
}) => WeeklyCalendarEvent(
  id: 'event-design-1',
  title: title,
  artistName: artistName,
  artistProfileId: artistProfileId,
  bandProfileId: bandProfileId,
  performerType: performerType,
  venueName: venueName,
  venueId: venueId,
  city: city,
  district: district,
  neighborhood: neighborhood,
  eventDate: '06.09.2026',
  startTime: '20:00:00',
  endTime: '22:00:00',
  description: description,
);

VenueEventDetail _detail({required String? description}) => VenueEventDetail(
  id: 'event-design-1',
  shareUrl: null,
  posterImage: null,
  performerName: 'bugrasahin',
  musicianProfileId: null,
  description: description,
);

VenueEventDetail _shareDetail({
  String id = 'event-design-1',
  bool linked = false,
  String? description = 'Mekânın etkinlik için yazdığı güncel açıklama.',
}) => VenueEventDetail(
  id: id,
  shareUrl: 'https://soundconnect.app/event/event-design-1',
  posterImage: 'https://example.invalid/new-poster.png',
  performerName: 'Yeni sanatçı',
  musicianProfileId: linked ? 'current-profile-id' : null,
  performerType: linked ? 'MUSICIAN' : 'MANUAL',
  title: 'Güncel etkinlik',
  description: description,
  eventDate: DateTime(2026, 9, 12),
  startTime: '21:30:00',
  endTime: '23:00:00',
  venueId: 'current-venue-id',
  venueName: 'yenimekan',
  venueCity: 'İstanbul',
  venueDistrict: 'Kadıköy',
);

final Uint8List _sharePng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

PreparedEventShare _prepared(EventShareData data) =>
    PreparedEventShare(bytes: _sharePng, data: data);

Future<void> _pumpShareSheet(WidgetTester tester) async {
  // The underlying share button intentionally animates while the preview is
  // open, so pumpAndSettle would wait forever for that progress indicator.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

class _EventShareService implements EventShareService {
  final preparedData = <EventShareData>[];
  final shared = <(PreparedEventShare, EventShareTarget)>[];
  Completer<PreparedEventShare>? preparation;
  Completer<void>? sending;
  bool failPreparation = false;
  bool failSending = false;

  @override
  Future<PreparedEventShare> prepare(
    BuildContext context,
    EventShareData data,
  ) async {
    preparedData.add(data);
    if (failPreparation) throw StateError('Preparation failed.');
    return preparation?.future ?? _prepared(data);
  }

  @override
  Future<void> share(
    BuildContext context,
    PreparedEventShare prepared,
    EventShareTarget target,
  ) async {
    shared.add((prepared, target));
    if (failSending) throw StateError('Share failed.');
    await sending?.future;
  }
}

class _DetailRepository extends Fake implements VenueEventRepository {
  Result<VenueEventDetail> result = const Result.failure(
    AppError(code: 'unavailable', message: 'Details unavailable.'),
  );
  Completer<Result<VenueEventDetail>>? completion;
  final requestedIds = <String>[];

  @override
  Future<Result<VenueEventDetail>> getDetail(String eventId) async {
    requestedIds.add(eventId);
    return completion?.future ?? result;
  }
}

class _MusicianRepository extends Fake implements MusicianProfileRepository {
  final requestedIds = <String>[];
  Result<MusicianProfile> result = const Result.failure(
    AppError(code: 'unavailable', message: 'Profile image unavailable.'),
  );
  Completer<Result<MusicianProfile>>? completion;
  Result<MusicianProfile> myResult = const Result.failure(
    AppError(code: 'unavailable', message: 'Profile unavailable.'),
  );
  Completer<Result<MusicianProfile>>? myCompletion;
  int myReads = 0;
  bool throwMyRead = false;

  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String profileId,
  ) async {
    requestedIds.add(profileId);
    return completion?.future ?? result;
  }

  @override
  Future<Result<MusicianProfile>> getMyProfile() async {
    myReads++;
    if (throwMyRead) throw StateError('Profile request unavailable.');
    return myCompletion?.future ?? myResult;
  }
}

class _BandRepository extends Fake implements BandRepository {
  final requestedIds = <String>[];

  @override
  Future<Result<BandProfile>> getPublicBandById(String bandId) async {
    requestedIds.add(bandId);
    return const Result.failure(
      AppError(code: 'unavailable', message: 'Profile image unavailable.'),
    );
  }
}

class _VenueRepository extends Fake implements VenueProfileRepository {
  final requestedIds = <String?>[];

  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async {
    requestedIds.add(venueId);
    return Result.success(
      VenuePublicProfile(
        venueProfileId: 'venue-profile-id',
        venueId: venueId!,
        ownerUserId: 'venue-owner-id',
        venueName: 'soundconnectankarauzunmekankullaniciadi',
        bio: null,
        profilePictureUrl: 'https://example.invalid/venue.jpg',
        instagramUrl: null,
        youtubeUrl: null,
        websiteUrl: null,
        address: null,
        phone: null,
        website: null,
        description: null,
        musicStartTime: null,
        cityName: 'Ankara',
        districtName: 'Çankaya',
        neighborhoodName: 'Çayyolu',
        activeMusicians: const [],
        activeBands: const [],
        weeklyEvents: const [],
      ),
    );
  }
}

class _CommentsRepository extends Fake implements EngagementRepository {
  final comments = <CommentItem>[];
  final creations = <(String, String, String)>[];
  int listCalls = 0;

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    listCalls++;
    return Result.success(
      CommentPage(items: List.of(comments), totalElements: comments.length),
    );
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    creations.add((targetType, targetId, text));
    final comment = CommentItem(
      id: 'comment-${creations.length}',
      user: const CommentUserSummary(
        id: 'commenter',
        username: 'dinleyici',
        avatarUrl: null,
      ),
      text: text,
      deleted: false,
      parentCommentId: parentCommentId,
      replyCount: 0,
      createdAt: DateTime(2026, 9, 5, 22),
    );
    comments.add(comment);
    return Result.success(comment);
  }
}
