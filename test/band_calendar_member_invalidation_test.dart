import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_calendar_repository_factory.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/musician_calendar_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/musician_profile_calendar_slot.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_carousel.dart';

void main() {
  test(
    'settings confirmations refresh each live calendar once without a loop',
    () async {
      final api = _CalendarApi();
      final personal = MusicianCalendarRepositoryImpl(
        api,
        sessionKeyProvider: () => 'founder',
      );
      final factory = BandCalendarRepositoryFactory(
        api,
        sessionKeyProvider: () => 'founder',
        refreshes: personal.changes,
        onSettingsConfirmed: personal.invalidate,
      );
      final band = factory.acquire('band');
      final otherBand = factory.acquire('other');
      final counts = [0, 0, 0];
      final subscriptions = [
        personal.changes.listen((_) => counts[0]++),
        band.changes.listen((_) => counts[1]++),
        otherBand.changes.listen((_) => counts[2]++),
      ];
      addTearDown(() async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await factory.dispose();
        await personal.dispose();
      });

      final updated = await band.updateSettings(visible: false, version: 0);
      expect(updated.isSuccess, isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(counts, [1, 1, 1]);
      expect(api.settingsWrites, 1);
      expect(api.settingsReads, 0);

      // A read also reconciles a committed hide after a lost write response.
      final reread = await band.getSettings();
      expect(reread.data!.visible, isFalse);
      await Future<void>.delayed(Duration.zero);
      expect(counts, [2, 2, 2]);
      expect(api.settingsReads, 1);

      band.invalidate();
      await Future<void>.delayed(Duration.zero);
      expect(counts, [2, 3, 2]);
      expect(api.calendarReads, 0);
    },
  );

  test(
    'failed or unconfirmed settings never emit a successful refresh',
    () async {
      final api = _CalendarApi()..invalidSettings = true;
      var confirmations = 0;
      final repository = MusicianCalendarRepositoryImpl(
        api,
        sessionKeyProvider: () => 'founder',
        targetBandId: 'band',
        onSettingsConfirmed: () => confirmations++,
      );
      addTearDown(repository.dispose);
      final read = await repository.getSettings();
      final write = await repository.updateSettings(visible: false, version: 0);
      expect(read.isSuccess, isFalse);
      expect(write.isSuccess, isFalse);
      expect(confirmations, 0);
    },
  );

  testWidgets('revoked member publication clears a mounted musician profile', (
    tester,
  ) async {
    final api = _CalendarApi();
    final personal = MusicianCalendarRepositoryImpl(
      api,
      sessionKeyProvider: () => 'founder',
    );
    final factory = BandCalendarRepositoryFactory(
      api,
      sessionKeyProvider: () => 'founder',
      refreshes: personal.changes,
      onSettingsConfirmed: personal.invalidate,
    );
    factory.acquire('band');
    addTearDown(() async {
      await factory.dispose();
      await personal.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                const Text('Aktif Mekanlar'),
                const Text('SoundConnect Ankara'),
                MusicianProfileCalendarSlot(
                  profileId: 'artist',
                  repository: personal,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final carousel = find.byType(WeeklyEventCarousel);
    expect(
      tester.widget<WeeklyEventCarousel>(carousel).items.single.id,
      'band-event',
    );
    final baselineReads = api.calendarReads;
    // The member hid this individual event. A fresh public feed is the only
    // authority used by an already-mounted profile.
    api.bandVisible = false;
    personal.invalidate();
    await tester.pumpAndSettle();
    expect(api.bandVisible, isFalse);
    expect(api.settingsReads, 0);
    expect(api.settingsWrites, 0);
    expect(api.calendarReads, baselineReads + 1);
    expect(carousel, findsNothing);
    expect(find.text('Haftalık Takvim'), findsNothing);
    expect(find.text('Aktif Mekanlar'), findsOneWidget);
    expect(find.text('SoundConnect Ankara'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // This remains quiet after the refresh has settled: no feedback polling.
    await tester.pump(const Duration(seconds: 30));
    expect(api.calendarReads, baselineReads + 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _CalendarApi implements ApiClient {
  bool bandVisible = true;
  bool invalidSettings = false;
  int version = 0;
  int settingsReads = 0;
  int settingsWrites = 0;
  int calendarReads = 0;

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    expect(path, '/api/v1/user/bands/band/calendar-settings');
    expect(requestContext?.expectedSessionKey, 'founder');
    if (method == ApiHttpMethod.put) {
      settingsWrites++;
      final update = body! as Map<String, Object>;
      expect(update['version'], version);
      bandVisible = update['visible']! as bool;
      version++;
    } else {
      expect(method, ApiHttpMethod.get);
      settingsReads++;
    }
    return decoder!({
      'visible': invalidSettings ? 'unconfirmed' : bandVisible,
      'version': version,
    });
  }

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    expect(path, '/api/v1/public/musician-profiles/artist/calendar');
    calendarReads++;
    return decoder!({
      'profileId': 'artist',
      'visible': true,
      'startDate': query!['startDate'],
      'endDate': query['endDate'],
      'page': query['page'],
      'size': query['size'],
      'hasNext': false,
      'events': [
        if (bandVisible)
          {
            'id': 'band-event',
            'title': 'Şahbaz Akustik Gecesi',
            'performerType': 'BAND',
            'bandId': 'band',
            'musicianProfileId': null,
            'performerName': 'Şahbaz',
            'eventDate': query['startDate'],
            'startTime': '21:00:00',
            'endTime': '23:00:00',
            'venueId': 'venue',
            'venueName': 'SoundConnect Ankara',
          },
      ],
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
