import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_event_management_event_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_carousel.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/event_poster_fallback.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  testWidgets(
    'default artwork fits thumbnail, carousel and large poster sizes',
    (tester) async {
      final semantics = tester.ensureSemantics();
      for (final size in const [
        Size(68, 80),
        Size(174, 128),
        Size(160, 200),
        Size(280, 400),
        Size(600, 400),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                devicePixelRatio: 3,
                textScaler: TextScaler.linear(2),
              ),
              child: Center(
                child: SizedBox.fromSize(
                  size: size,
                  child: const EventPosterFallback(
                    title: 'Şahbaz ile Akustik Bir Gece',
                    dateLabel: '08.09.2026 • 21:00',
                    showDetails: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size');
        expect(find.byType(Image), findsOneWidget);
        final emblem = tester.widget<Image>(find.byType(Image));
        expect(emblem.image, isA<ResizeImage>());
        final resized = emblem.image as ResizeImage;
        expect(resized.imageProvider, isA<AssetImage>());
        expect(
          (resized.imageProvider as AssetImage).assetName,
          'assets/logo.png',
        );
        expect(resized.width, inInclusiveRange(1, 512));
        expect(resized.height, resized.width);
        if (size == const Size(600, 400)) {
          expect(resized.width, 512);
        }
        final artwork = find.byType(EventPosterFallback);
        final title = find.text('Şahbaz ile Akustik Bir Gece');
        if (size.height >= 400) {
          expect(title, findsOneWidget);
          expect(
            tester.getTopLeft(title).dy,
            greaterThan(tester.getBottomLeft(find.byType(Image)).dy),
          );
          expect(
            tester.getBottomLeft(find.text('08.09.2026 • 21:00')).dy,
            lessThan(tester.getBottomLeft(artwork).dy),
          );
        } else {
          expect(title, findsNothing);
        }
        expect(
          find.bySemanticsLabel(
            'Şahbaz ile Akustik Bir Gece için etkinlik afişi',
          ),
          findsOneWidget,
        );
      }
      semantics.dispose();
    },
  );

  testWidgets('default artwork decodes the bundled SoundConnect emblem', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 280,
            height: 400,
            child: EventPosterFallback(title: 'Logo doğrulama'),
          ),
        ),
      ),
    );
    final emblemFinder = find.descendant(
      of: find.byType(EventPosterFallback),
      matching: find.byType(Image),
    );
    final emblem = tester.widget<Image>(emblemFinder);
    expect(emblem.image, isA<ResizeImage>());
    final provider = emblem.image as ResizeImage;
    expect(provider.imageProvider, isA<AssetImage>());
    expect((provider.imageProvider as AssetImage).assetName, 'assets/logo.png');

    // Await the same resized provider used by the real widget outside the
    // fake test clock, so a missing or corrupt bundled asset cannot pass.
    Object? decodeError;
    await tester.runAsync(() async {
      await precacheImage(
        provider,
        tester.element(emblemFinder),
        onError: (error, _) => decodeError = error,
      ).timeout(const Duration(seconds: 10));
    });
    await tester.pump();

    expect(decodeError, isNull);
    expect(tester.takeException(), isNull);
    final raster = tester.widget<RawImage>(
      find.descendant(of: emblemFinder, matching: find.byType(RawImage)),
    );
    expect(raster.image, isNotNull);
    expect(raster.image!.width, greaterThan(0));
    expect(raster.image!.height, greaterThan(0));
    expect(raster.image!.width, provider.width);
    expect(raster.image!.height, provider.height);
  });

  testWidgets(
    'management cards share artwork for missing and invalid posters',
    (tester) async {
      for (final poster in <String?>[null, ' ', 'file:///private/poster.jpg']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: VenueCalendarEventCard(
                  posterImage: poster,
                  title: 'Şahbaz Gecesi',
                  dateLabel: '08.09.2026',
                  timeLabel: '21:00',
                  performerName: 'Şahbaz',
                  onTap: () {},
                  saving: false,
                  onDelete: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(EventPosterFallback), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('carousel recovers failed assets and updates reused artwork', (
    tester,
  ) async {
    for (final title in ['İlk Gece', 'İkinci Gece']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeeklyEventCarousel(
              items: [
                _event(title: title, poster: 'assets/missing-poster.png'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final poster = tester.widget<EventPosterFallback>(
        find.byType(EventPosterFallback),
      );
      expect(poster.title, title);
    }
  });

  testWidgets('weekly carousel fits long titles with 300 percent text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final compact in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(3)),
            child: Scaffold(
              body: WeeklyEventCarousel(
                compactTitle: compact,
                items: [_event(title: 'Şahbaz ile Akustik Bir Gece')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(EventPosterFallback), findsOneWidget);
    }
  });

  testWidgets('thin outline approval stays usable at 320dp and 200% text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _RequestRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: EventPerformerRequestsScreen(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final accept = find.byKey(const Key('accept-event-request-request-1'));
    await tester.scrollUntilVisible(
      accept,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final button = tester.widget<GradientOutlineButton>(accept);
    expect(button.strokeWidth, 0.8);
    expect(tester.getSize(accept).height, greaterThanOrEqualTo(48));
    await tester.tap(accept);
    await tester.pump();
    expect(tester.widget<GradientOutlineButton>(accept).loading, isTrue);
    expect(tester.widget<GradientOutlineButton>(accept).onPressed, isNull);
    await tester.tap(accept, warnIfMissed: false);
    expect(repository.acceptCalls, 1);
    expect(tester.takeException(), isNull);
    repository.completion.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(find.text('Bekleyen etkinlik daveti yok'), findsOneWidget);
  });
}

WeeklyCalendarEvent _event({required String title, String? poster}) =>
    WeeklyCalendarEvent(
      id: 'poster-event',
      title: title,
      artistName: 'Şahbaz',
      artistProfileId: null,
      performerType: 'MANUAL',
      venueName: 'SoundConnect Ankara',
      venueId: null,
      city: 'Ankara',
      district: 'Çankaya',
      neighborhood: 'Kızılay',
      eventDate: '08.09.2026',
      startTime: '21:00',
      endTime: '23:00',
      imageAssetPath: poster,
      description: '',
    );

class _RequestRepository implements EventPerformerRequestRepository {
  @override
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  }) => throw UnimplementedError('Unexpected reconsideration in visual test.');

  final completion = Completer<Result<void>>();
  int acceptCalls = 0;

  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async => Result.success(
    EventPerformerRequestPage(
      items: acceptCalls == 0
          ? [
              EventPerformerRequest(
                requestId: 'request-1',
                eventId: 'event-1',
                eventTitle: 'Şahbaz ile Akustik Bir Gece',
                eventDate: DateTime(2026, 9, 8),
                startTime: '21:00:00',
                endTime: '23:00:00',
                venueId: 'venue-1',
                venueName: 'SoundConnect Ankara',
                venueProfilePictureUrl: null,
                targetType: EventPerformerTargetType.band,
                targetId: 'band-1',
                musicianProfileId: null,
                bandId: 'band-1',
                performerName: 'Şahbaz',
                status: EventPerformerRequestStatus.pending,
                profileCalendarApproved: false,
                decisionAllowed: true,
                canReconsider: false,
                expired: false,
                serverNow: DateTime.utc(2026, 9, 6),
                eventStartsAt: DateTime.utc(2026, 9, 8, 18),
                createdAt: DateTime(2026, 9, 5),
                decidedAt: null,
              ),
            ]
          : [],
      page: 0,
      size: 20,
      totalElements: acceptCalls == 0 ? 1 : 0,
      totalPages: acceptCalls == 0 ? 1 : 0,
      hasNext: false,
    ),
  );

  @override
  Future<Result<void>> accept(String requestId, {bool showOnProfile = false}) {
    acceptCalls++;
    return completion.future;
  }

  @override
  Future<Result<void>> reject(String requestId) async =>
      const Result.success(null);
}
