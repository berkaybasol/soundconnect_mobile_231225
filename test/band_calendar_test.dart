import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_calendar_repository_factory.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_profile_calendar_slot.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_carousel.dart';

void main() {
  late _BandApi api;
  late StreamController<void> refreshes;
  late BandCalendarRepositoryFactory factory;
  String? session;
  final start = DateTime.utc(2026, 9, 5);
  final end = DateTime.utc(2026, 9, 11);

  setUp(() async {
    await serviceLocator.reset();
    api = _BandApi();
    session = 'founder';
    refreshes = StreamController<void>.broadcast();
    factory = BandCalendarRepositoryFactory(
      api,
      sessionKeyProvider: () => session,
      refreshes: refreshes.stream,
    );
  });

  tearDown(() async {
    await factory.dispose();
    await refreshes.close();
    await serviceLocator.reset();
  });

  test(
    'band settings use the band path and a fenced founder session',
    () async {
      final repository = factory.acquire('band');
      final initial = await repository.getSettings();
      expect(initial.data?.visible, isFalse);
      expect(api.path, '/api/v1/user/bands/band/calendar-settings');
      expect(api.expectedSession, 'founder');
      final updated = await repository.updateSettings(
        visible: true,
        version: 0,
      );
      expect(updated.data?.visible, isTrue);
      expect(updated.data?.version, 1);
      expect(api.lastBody, {'visible': true, 'version': 0});
      expect(api.method, ApiHttpMethod.put);
    },
  );

  test('band public calendar accepts only its exact band performer', () async {
    api.visible['band'] = true;
    final repository = factory.acquire('band');
    final result = await repository.getCalendar(
      profileId: 'band',
      startDate: start,
      endDate: end,
    );
    expect(result.isSuccess, isTrue);
    expect(api.path, '/api/v1/public/bands/band/calendar');
    expect(result.data!.events.single.bandId, 'band');
    expect(result.data!.events.single.musicianProfileId, isNull);
  });

  for (final badIdentity in [
    {'performerType': 'BAND', 'bandId': 'other', 'musicianProfileId': null},
    {'performerType': 'MUSICIAN', 'bandId': null, 'musicianProfileId': 'band'},
    {'performerType': 'BAND', 'bandId': 'band', 'musicianProfileId': 'artist'},
    {'performerType': 'BAND', 'bandId': 7, 'musicianProfileId': null},
  ]) {
    test(
      'band rejects a mismatched or ambiguous identity $badIdentity',
      () async {
        api.visible['band'] = true;
        api.eventOverrides = badIdentity;
        final repository = factory.acquire('band');
        final result = await repository.getCalendar(
          profileId: 'band',
          startDate: start,
          endDate: end,
        );
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
      },
    );
  }

  test('a band-scoped repository cannot query a different profile', () async {
    final repository = factory.acquire('band');
    final result = await repository.getCalendar(
      profileId: 'other',
      startDate: start,
      endDate: end,
    );
    expect(result.isSuccess, isFalse);
    expect(api.calendarCalls, 0);
  });

  test('guest cannot update band settings', () async {
    session = null;
    final repository = factory.acquire('band');
    final result = await repository.updateSettings(visible: true, version: 0);
    expect(result.isSuccess, isFalse);
    expect(api.settingsWrites, 0);
  });

  test(
    'profile and settings share a band instance until both release',
    () async {
      final profileRepository = factory.acquire(' band ');
      final settingsRepository = factory.acquire('band');
      expect(identical(profileRepository, settingsRepository), isTrue);
      final done = Completer<void>();
      var changes = 0;
      profileRepository.changes.listen((_) => changes++, onDone: done.complete);
      await factory.release('band');
      expect(done.isCompleted, isFalse);
      settingsRepository.invalidate();
      await Future<void>.delayed(Duration.zero);
      expect(changes, 1);
      await factory.release('band');
      expect(done.isCompleted, isTrue);
      final nextVisit = factory.acquire('band');
      expect(identical(nextVisit, profileRepository), isFalse);
    },
  );

  test(
    'approvals refresh live bands and disposal cancels the forwarding',
    () async {
      final band = factory.acquire('band');
      final other = factory.acquire('other');
      final first = band.changes.first;
      final second = other.changes.first;
      refreshes.add(null);
      await Future.wait([first, second]);
      await factory.dispose();
      refreshes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(() => factory.acquire('band'), throwsStateError);
      await factory.release('band');
    },
  );

  Widget surface({String id = 'band'}) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Text('Aktif Mekanlar'),
            const Text('SoundConnect Ankara'),
            BandProfileCalendarSlot(bandId: id, factory: factory),
          ],
        ),
      ),
    ),
  );

  testWidgets('unpublished band feed does not remove the band venues', (
    tester,
  ) async {
    await tester.pumpWidget(surface());
    await tester.pumpAndSettle();
    expect(find.text('Haftalık Takvim'), findsNothing);
    expect(find.byType(WeeklyEventCarousel), findsNothing);
    expect(find.text('Aktif Mekanlar'), findsOneWidget);
    expect(find.text('SoundConnect Ankara'), findsOneWidget);
  });

  testWidgets(
    'empty published band feed occupies no space and preserves venues',
    (tester) async {
      api.visible['band'] = true;
      api.emptyCalendar = true;
      await tester.pumpWidget(surface());
      await tester.pumpAndSettle();
      expect(find.text('Haftalık Takvim'), findsNothing);
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Aktif Mekanlar'), findsOneWidget);
      expect(find.text('SoundConnect Ankara'), findsOneWidget);
      expect(tester.getSize(find.byType(BandProfileCalendarSlot)).height, 0);
      expect(api.settingsReads, 0);
      expect(api.settingsWrites, 0);
    },
  );

  testWidgets('changing band cannot display another band calendar', (
    tester,
  ) async {
    api.visible['band'] = true;
    await tester.pumpWidget(surface());
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyEventCarousel), findsOneWidget);
    await tester.pumpWidget(surface(id: 'other'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyEventCarousel), findsNothing);
    expect(find.text('Aktif Mekanlar'), findsOneWidget);
    expect(api.path, '/api/v1/public/bands/other/calendar');
  });

  testWidgets(
    'band calendar failure cannot remove active venues or leak stale cards',
    (tester) async {
      api.visible['band'] = true;
      await tester.pumpWidget(surface());
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyEventCarousel), findsOneWidget);
      api.failCalendar = true;
      // The app-scoped refresh subscription is created in setUp, outside the
      // widget test's fake-clock zone. Drain that stream's real event loop.
      await tester.runAsync(() async {
        refreshes.add(null);
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(api.calendarCalls, 2);
      expect(find.byType(WeeklyEventCarousel), findsNothing);
      expect(find.text('Aktif Mekanlar'), findsOneWidget);
      expect(find.text('SoundConnect Ankara'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _BandApi implements ApiClient {
  final Map<String, bool> visible = {};
  final Map<String, int> versions = {};
  Map<String, Object?>? eventOverrides;
  String? path;
  ApiHttpMethod? method;
  String? expectedSession;
  Object? lastBody;
  int settingsReads = 0;
  int settingsWrites = 0;
  int calendarCalls = 0;
  bool failCalendar = false;
  bool emptyCalendar = false;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    this.path = path;
    calendarCalls++;
    if (failCalendar) throw StateError('Offline');
    final bandId = Uri.decodeComponent(path.split('/')[5]);
    final shown = visible[bandId] ?? false;
    return decoder!({
      'profileId': bandId,
      'visible': shown,
      'startDate': query!['startDate'],
      'endDate': query['endDate'],
      'page': query['page'],
      'size': query['size'],
      'hasNext': false,
      'events': shown && !emptyCalendar
          ? [
              <String, Object?>{
                'id': 'event-$bandId',
                'title': 'Şahbaz Akustik Gecesi',
                'performerType': 'BAND',
                'musicianProfileId': null,
                'bandId': bandId,
                'performerName': 'Şahbaz',
                'eventDate': query['startDate'],
                'startTime': '21:00:00',
                'endTime': '23:00:00',
                'venueId': 'venue',
                'venueName': 'SoundConnect Ankara',
                ...?eventOverrides,
              },
            ]
          : [],
    });
  }

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    this.path = path;
    this.method = method;
    expectedSession = requestContext?.expectedSessionKey;
    lastBody = body;
    final bandId = Uri.decodeComponent(path.split('/')[5]);
    if (method == ApiHttpMethod.put) {
      settingsWrites++;
      final update = body! as Map<String, Object>;
      visible[bandId] = update['visible']! as bool;
      versions[bandId] = (versions[bandId] ?? 0) + 1;
    } else {
      settingsReads++;
    }
    return decoder!({
      'visible': visible[bandId] ?? false,
      'version': versions[bandId] ?? 0,
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
