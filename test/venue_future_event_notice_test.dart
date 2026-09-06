import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_item.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_future_event_notice.dart';

void main() {
  test('inclusive seven-day window ignores time of day', () {
    final now = DateTime(2026, 9, 6, 23, 59);
    expect(isVenueEventBeyondWeek(DateTime(2026, 9, 6), now: now), isFalse);
    expect(
      isVenueEventBeyondWeek(DateTime(2026, 9, 12, 23, 59), now: now),
      isFalse,
    );
    expect(isVenueEventBeyondWeek(DateTime(2026, 9, 13), now: now), isTrue);
    expect(
      venueEventProfileVisibleFrom(DateTime(2026, 9, 15)),
      DateTime(2026, 9, 9),
    );
    expect(
      isVenueEventBeyondWeek(DateTime(2026, 9, 15), now: DateTime(2026, 9, 9)),
      isFalse,
    );
  });
  for (final value in [
    (DateTime(2027, 1, 3), DateTime(2026, 12, 28)),
    (DateTime(2028, 3, 4), DateTime(2028, 2, 27)),
    (DateTime(2027, 3, 4), DateTime(2027, 2, 26)),
  ]) {
    test('publication date crosses calendar boundary ${value.$1}', () {
      expect(venueEventProfileVisibleFrom(value.$1), value.$2);
    });
  }
  testWidgets(
    'future notice gives exact date without confirmation at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: VenueFutureEventNotice(
                    eventDate: DateTime(2026, 9, 15),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('9 Eylül 2026 tarihinden itibaren'),
        findsOneWidget,
      );
      expect(find.textContaining('Gelecek Etkinlikler'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
