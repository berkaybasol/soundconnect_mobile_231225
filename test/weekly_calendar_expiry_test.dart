import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_calendar.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_calendar_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/weekly_calendar_date_policy.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_calendar_slot.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_carousel.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';

void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());

  test('calendar window is Istanbul today plus six civil dates', () {
    for (final input in [
      '2026-09-08T21:00:00Z',
      '2026-09-09T00:00:00+03:00',
      '2026-09-08T14:00:00-07:00',
    ]) {
      final now = DateTime.parse(input);
      final today = WeeklyCalendarDatePolicy.today(now);
      expect(today, DateTime(2026, 9, 9));
      for (var offset = -1; offset <= 7; offset++) {
        expect(
          WeeklyCalendarDatePolicy.contains(
            DateTime.utc(2026, 9, 9 + offset),
            today,
          ),
          offset >= 0 && offset <= 6,
        );
      }
      expect(
        WeeklyCalendarDatePolicy.untilNextDay(now),
        const Duration(days: 1),
      );
    }
    expect(
      WeeklyCalendarDatePolicy.today(DateTime.parse('2026-12-31T21:00:00Z')),
      DateTime(2027),
    );
    expect(WeeklyCalendarDatePolicy.parseDisplayDate('31.02.2026'), isNull);
    expect(WeeklyCalendarDatePolicy.parseDisplayDate('-'), isNull);
  });

  testWidgets(
    'ended today remains until Istanbul midnight and expired tap is inert',
    (tester) async {
      var now = DateTime.parse('2026-09-08T20:59:59Z');
      await tester.pumpWidget(
        _host(
          WeeklyEventCarousel(
            now: () => now,
            trackImpressions: false,
            items: [_event('today', '08.09.2026')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weekly-event-today')), findsOneWidget);
      final retained = tester
          .widget<InkWell>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('weekly-event-today')),
                  matching: find.byType(InkWell),
                )
                .first,
          )
          .onTap!;
      now = DateTime.parse('2026-09-08T21:00:00Z');
      // Even a callback retained before the timer's next frame cannot open it.
      retained();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weekly-event-today')), findsNothing);
      expect(find.text('Bu hafta için etkinlik bulunamadı.'), findsOneWidget);
      expect(find.byType(WeeklyEventDetailScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'cached venue calendar excludes history invalid dates and beyond next seven days',
    (tester) async {
      final now = DateTime.parse('2026-09-09T00:30:00Z');
      await tester.pumpWidget(
        _host(
          WeeklyEventCarousel(
            now: () => now,
            trackImpressions: false,
            items: [
              _event('past', '08.09.2026'),
              _event('today', '09.09.2026'),
              _event('next-week', '16.09.2026'),
              _event('invalid', '-'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weekly-event-today')), findsOneWidget);
      for (final id in ['past', 'next-week', 'invalid']) {
        expect(find.byKey(ValueKey('weekly-event-$id')), findsNothing);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'resume expires cached cards without waiting for suspended timer',
    (tester) async {
      var now = DateTime.parse('2026-09-08T20:00:00Z');
      await tester.pumpWidget(
        _host(
          WeeklyEventCarousel(
            now: () => now,
            trackImpressions: false,
            items: [_event('today', '08.09.2026')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      now = DateTime.parse('2026-09-09T06:00:00Z');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weekly-event-today')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final profile in ['musician', 'band']) {
    testWidgets(
      '$profile midnight reloads page zero with fresh range and clears revoked snapshot',
      (tester) async {
        var now = DateTime.parse('2026-09-08T20:59:59Z');
        final repo = _CalendarRepository();
        await tester.pumpWidget(
          _host(
            MusicianProfileCalendarSlot(
              profileId: profile,
              repository: repo,
              now: () => now,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(repo.ranges.single, (
          DateTime.utc(2026, 9, 8),
          DateTime.utc(2026, 9, 14),
          0,
        ));
        final pending = Completer<Result<MusicianCalendarPage>>();
        repo.pending = pending.future;
        now = DateTime.parse('2026-09-08T21:00:00Z');
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(WeeklyEventCarousel), findsNothing);
        expect(repo.ranges.last, (
          DateTime.utc(2026, 9, 9),
          DateTime.utc(2026, 9, 15),
          0,
        ));
        pending.complete(
          Result.success(
            _page(profile, DateTime.utc(2026, 9, 9), visible: false),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Haftalık Takvim'), findsNothing);
        expect(repo.ranges, hasLength(2));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('midnight read cannot restore previous profile after rebind', (
    tester,
  ) async {
    var now = DateTime.parse('2026-09-08T20:59:59Z');
    final repo = _CalendarRepository();
    Widget slot(String id) => _host(
      MusicianProfileCalendarSlot(
        profileId: id,
        repository: repo,
        now: () => now,
      ),
    );
    await tester.pumpWidget(slot('old'));
    await tester.pumpAndSettle();
    final pending = Completer<Result<MusicianCalendarPage>>();
    repo.pending = pending.future;
    now = DateTime.parse('2026-09-08T21:00:00Z');
    await tester.pump(const Duration(seconds: 1));
    repo.pending = null;
    repo.visible = false;
    await tester.pumpWidget(slot('new'));
    await tester.pumpAndSettle();
    pending.complete(Result.success(_page('old', DateTime.utc(2026, 9, 9))));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyEventCarousel), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'resume after midnight refreshes despite fifteen-second throttle',
    (tester) async {
      var now = DateTime.parse('2026-09-08T20:59:59Z');
      final repo = _CalendarRepository();
      await tester.pumpWidget(
        _host(
          MusicianProfileCalendarSlot(
            profileId: 'artist',
            repository: repo,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      now = DateTime.parse('2026-09-08T21:00:01Z');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repo.ranges, hasLength(2));
      expect(repo.ranges.last.$1, DateTime.utc(2026, 9, 9));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

WeeklyCalendarEvent _event(String id, String date) => WeeklyCalendarEvent(
  id: id,
  title: id,
  artistName: 'Sanatçı',
  artistProfileId: 'artist',
  performerType: 'MUSICIAN',
  venueName: 'Mekan',
  venueId: 'venue',
  city: '',
  district: '',
  neighborhood: '',
  eventDate: date,
  startTime: '10:00',
  endTime: '12:00',
  description: '',
);

MusicianCalendarPage _page(String id, DateTime day, {bool visible = true}) =>
    MusicianCalendarPage(
      profileId: id,
      visible: visible,
      startDate: day,
      endDate: day.add(const Duration(days: 6)),
      page: 0,
      size: 20,
      hasNext: false,
      events: visible
          ? [
              VenueEventDetail(
                id: 'event-$id',
                shareUrl: null,
                posterImage: null,
                performerName: 'Sanatçı',
                musicianProfileId: 'artist',
                performerType: 'MUSICIAN',
                title: 'Etkinlik',
                eventDate: day,
                venueId: 'venue',
                venueName: 'Mekan',
                startTime: '10:00:00',
                endTime: '12:00:00',
              ),
            ]
          : const [],
    );

class _CalendarRepository extends Fake implements MusicianCalendarRepository {
  final ranges = <(DateTime, DateTime, int)>[];
  Future<Result<MusicianCalendarPage>>? pending;
  bool visible = true;
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<Result<MusicianCalendarPage>> getCalendar({
    required String profileId,
    required DateTime startDate,
    required DateTime endDate,
    int page = 0,
    int size = 20,
  }) async {
    ranges.add((startDate, endDate, page));
    return pending ??
        Result.success(_page(profileId, startDate, visible: visible));
  }
}
