import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_calendar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_calendar_slot.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_carousel.dart';

void main() {
  late _Repository repository;
  setUp(() async {
    await serviceLocator.reset();
    repository = _Repository();
  });
  tearDown(() async {
    await repository.dispose();
    await serviceLocator.reset();
  });

  Widget slot({String id = 'artist', Object? refresh, bool compact = false}) =>
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const Text('Çaldığı Mekanlar'),
              MusicianProfileCalendarSlot(
                profileId: id,
                repository: repository,
                refreshToken: refresh,
                compactTitle: compact,
              ),
            ],
          ),
        ),
      );

  testWidgets(
    'calendar is independent from venue connections and hidden occupies no space',
    (tester) async {
      await tester.pumpWidget(slot());
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventCarousel), findsOneWidget);
      expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
      expect(find.text('Haftalık Takvim'), findsOneWidget);
      repository.visible = false;
      repository.invalidate();
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
      expect(find.text('Haftalık Takvim'), findsNothing);
      expect(
        tester.getSize(find.byType(MusicianProfileCalendarSlot)).height,
        0,
      );
    },
  );

  testWidgets(
    'decision invalidation refreshes already mounted profile automatically',
    (tester) async {
      repository.events = const [];
      await tester.pumpWidget(slot());
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Haftalık Takvim'), findsNothing);
      expect(
        tester.getSize(find.byType(MusicianProfileCalendarSlot)).height,
        0,
      );
      repository.events = [_event()];
      repository.invalidate();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<WeeklyEventCarousel>(find.byType(WeeklyEventCarousel))
            .items
            .single
            .id,
        'event',
      );
    },
  );

  testWidgets(
    'profile replacement discards slow response from previous profile',
    (tester) async {
      final old = Completer<Result<MusicianCalendarPage>>();
      repository.pendingCalendar = old.future;
      await tester.pumpWidget(slot(id: 'old'));
      repository.pendingCalendar = null;
      repository.visible = false;
      await tester.pumpWidget(slot(id: 'new'));
      await tester.pumpAndSettle();
      old.complete(Result.success(_page(profile: 'old')));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
    },
  );

  testWidgets(
    'failed refresh hides all calendar chrome until profile refresh succeeds',
    (tester) async {
      await tester.pumpWidget(slot());
      await tester.pumpAndSettle();
      repository.calendarError = const AppError(
        code: '503',
        message: 'Unavailable',
      );
      repository.invalidate();
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Haftalık Takvim'), findsNothing);
      expect(
        tester.getSize(find.byType(MusicianProfileCalendarSlot)).height,
        0,
      );
      expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
      repository.calendarError = null;
      await tester.pumpWidget(slot(refresh: Object()));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventCarousel), findsOneWidget);
    },
  );

  testWidgets('unknown visibility never flashes a calendar placeholder', (
    tester,
  ) async {
    final pending = Completer<Result<MusicianCalendarPage>>();
    repository.pendingCalendar = pending.future;
    await tester.pumpWidget(slot());
    expect(find.text('Haftalık Takvim'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.getSize(find.byType(MusicianProfileCalendarSlot)).height, 0);
    pending.complete(Result.success(_page(visible: false)));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(MusicianProfileCalendarSlot)).height, 0);
  });

  testWidgets(
    'server-ineligible feed stays hidden even if it contains events',
    (tester) async {
      repository.visible = false;
      repository.events = const [];
      await tester.pumpWidget(slot());
      await tester.pumpAndSettle();
      repository.events = [_event()];
      repository.invalidate();
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Haftalık Takvim'), findsNothing);
      expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
      repository.visible = true;
      repository.invalidate();
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventCarousel), findsOneWidget);
      expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
    },
  );

  testWidgets(
    'pagination revocation removes previously visible page immediately',
    (tester) async {
      repository.hasNext = true;
      await tester.pumpWidget(slot());
      await tester.pumpAndSettle();
      repository.visible = false;
      repository.hasNext = false;
      await tester.tap(find.byKey(const Key('musician-calendar-more')));
      await tester.pumpAndSettle();
      expect(repository.pages, [0, 1]);
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
    },
  );

  testWidgets(
    'fresh pages replace old eligibility snapshots and previous refetches',
    (tester) async {
      repository.hasNext = true;
      repository.events = [_event(id: 'now-hidden-band')];
      await tester.pumpWidget(slot());
      await tester.pumpAndSettle();
      repository.events = [_event(id: 'still-authorized')];
      repository.hasNext = false;
      await tester.tap(find.byKey(const Key('musician-calendar-more')));
      await tester.pumpAndSettle();
      expect(repository.pages, [0, 1]);
      expect(
        tester
            .widget<WeeklyEventCarousel>(find.byType(WeeklyEventCarousel))
            .items
            .map((item) => item.id),
        ['still-authorized'],
      );
      repository.events = [_event(id: 'fresh-first-page')];
      await tester.tap(find.byKey(const Key('musician-calendar-previous')));
      await tester.pumpAndSettle();
      expect(repository.pages, [0, 1, 0]);
      expect(
        tester
            .widget<WeeklyEventCarousel>(find.byType(WeeklyEventCarousel))
            .items
            .single
            .id,
        'fresh-first-page',
      );
    },
  );

  testWidgets(
    'paging clears old events immediately while the permission read is pending',
    (tester) async {
      repository.hasNext = true;
      await tester.pumpWidget(slot());
      await tester.pumpAndSettle();
      final pending = Completer<Result<MusicianCalendarPage>>();
      repository.pendingCalendar = pending.future;
      await tester.tap(find.byKey(const Key('musician-calendar-more')));
      await tester.pump();
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Çaldığı Mekanlar'), findsOneWidget);
      pending.complete(Result.success(_page(visible: false, page: 1)));
      await tester.pumpAndSettle();
      expect(find.text('Haftalık Takvim'), findsNothing);
    },
  );

  testWidgets(
    'repeated paging callbacks before rebuild are safe and single flight',
    (tester) async {
      repository.hasNext = true;
      await tester.pumpWidget(slot());
      await tester.pumpAndSettle();
      final next = tester
          .widget<TextButton>(find.byKey(const Key('musician-calendar-more')))
          .onPressed!;
      final pending = Completer<Result<MusicianCalendarPage>>();
      repository.pendingCalendar = pending.future;
      next();
      next();
      expect(repository.pages, [0, 1]);
      pending.complete(
        Result.success(_page(page: 1, hasNext: true, events: [_event()])),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final previous = tester
          .widget<TextButton>(
            find.byKey(const Key('musician-calendar-previous')),
          )
          .onPressed!;
      final pendingPrevious = Completer<Result<MusicianCalendarPage>>();
      repository.pendingCalendar = pendingPrevious.future;
      previous();
      previous();
      expect(repository.pages, [0, 1, 0]);
      pendingPrevious.complete(Result.success(_page()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'concurrent revocation exhausting a page reloads the first page once',
    (tester) async {
      repository.hasNext = true;
      await tester.pumpWidget(slot());
      await tester.pumpAndSettle();
      repository.events = const [];
      repository.hasNext = false;
      await tester.tap(find.byKey(const Key('musician-calendar-more')));
      await tester.pumpAndSettle();
      expect(repository.pages, [0, 1, 0]);
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Haftalık Takvim'), findsNothing);
      expect(find.byKey(const Key('musician-calendar-previous')), findsNothing);
    },
  );
}

VenueEventDetail _event({String id = 'event'}) => VenueEventDetail(
  id: id,
  shareUrl: null,
  posterImage: null,
  performerName: 'Buğra',
  musicianProfileId: 'artist',
  performerType: 'MUSICIAN',
  title: 'Gece',
  eventDate: DateTime.now(),
  venueId: 'venue',
  venueName: 'SoundConnect Ankara',
  startTime: '21:00:00',
);

MusicianCalendarPage _page({
  String profile = 'artist',
  bool visible = true,
  List<VenueEventDetail>? events,
  int page = 0,
  bool hasNext = false,
}) {
  final today = DateTime.now();
  return MusicianCalendarPage(
    profileId: profile,
    visible: visible,
    startDate: today,
    endDate: today.add(const Duration(days: 6)),
    events: visible ? (events ?? []) : [],
    page: page,
    size: 20,
    hasNext: hasNext,
  );
}

class _Repository extends Fake implements MusicianCalendarRepository {
  final controller = StreamController<void>.broadcast();
  bool visible = true;
  bool hasNext = false;
  List<VenueEventDetail> events = [_event()];
  AppError? calendarError;
  Future<Result<MusicianCalendarPage>>? pendingCalendar;
  final pages = <int>[];

  @override
  Stream<void> get changes => controller.stream;
  @override
  void invalidate() => controller.add(null);
  @override
  Future<void> dispose() => controller.close();
  @override
  Future<Result<MusicianCalendarPage>> getCalendar({
    required String profileId,
    required DateTime startDate,
    required DateTime endDate,
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    if (pendingCalendar != null) return pendingCalendar!;
    if (calendarError != null) return Result.failure(calendarError);
    final dated = events
        .map(
          (event) => VenueEventDetail(
            id: event.id,
            shareUrl: event.shareUrl,
            posterImage: event.posterImage,
            performerName: event.performerName,
            musicianProfileId: event.musicianProfileId,
            performerType: event.performerType,
            title: event.title,
            eventDate: startDate,
            startTime: event.startTime,
            venueId: event.venueId,
            venueName: event.venueName,
          ),
        )
        .toList();
    return Result.success(
      _page(
        profile: profileId,
        visible: visible,
        events: dated,
        page: page,
        hasNext: hasNext,
      ),
    );
  }
}
