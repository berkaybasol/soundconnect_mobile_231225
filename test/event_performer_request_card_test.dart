import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_request_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_request_copy.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/event_poster_fallback.dart';

void main() {
  for (final poster in <String?>[
    null,
    ' ',
    'file:///private/poster.jpg',
    'invalid',
  ]) {
    testWidgets('missing or unusable poster uses shared artwork: $poster', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventPerformerRequestCard(
                request: requestCardFixture(posterImage: poster),
                processing: false,
                onAccept: () {},
                onReject: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(EventPosterFallback), findsOneWidget);
      expect(
        tester
            .widget<EventPosterFallback>(find.byType(EventPosterFallback))
            .title,
        'Akustik Gece',
      );
      expect(
        tester
            .getSize(find.byKey(const Key('event-request-poster-preview')))
            .aspectRatio,
        greaterThanOrEqualTo(16 / 9),
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final brightness in Brightness.values) {
    for (final band in [false, true]) {
      testWidgets(
        'long request fits 320dp at 200 percent: $brightness band=$band',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final request = requestCardFixture(band: band, longNames: true);
          var accepted = 0;
          var rejected = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: EventPerformerRequestCard(
                      request: request,
                      processing: false,
                      onAccept: () => accepted++,
                      onReject: () => rejected++,
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(find.text('2026'), findsOneWidget);
          expect(find.text('EYL'), findsOneWidget);
          expect(find.text('20:00 – 22:00'), findsOneWidget);
          expect(
            find.text(
              band
                  ? 'Bu etkinliği grubun profilinde de göster'
                  : 'Bu etkinliği profilimde de göster',
            ),
            findsOneWidget,
          );
          final approve = find.byKey(const Key('accept-event-request-preview'));
          await tester.ensureVisible(approve);
          await tester.tap(approve);
          expect(accepted, 1);
          final reject = find.byKey(const Key('reject-event-request-preview'));
          await tester.ensureVisible(reject);
          await tester.tap(reject);
          expect(rejected, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'processing disables both actions without hiding permission copy',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventPerformerRequestCard(
                request: requestCardFixture(),
                processing: true,
                showOnProfile: true,
                onShowOnProfileChanged: (_) => calls++,
                onAccept: () => calls++,
                onReject: () => calls++,
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<GradientOutlineButton>(find.byType(GradientOutlineButton))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(find.textContaining('Sonradan gizleyebilirsin.'), findsNothing);
      expect(
        find.text(requestCardFixture().purposeExplanation),
        findsOneWidget,
      );
      expect(
        tester
            .widget<InkWell>(
              find.byKey(const Key('event-calendar-visibility-help-preview')),
            )
            .onTap,
        isNull,
      );
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('publication choice is controlled and starts unchecked', (
    tester,
  ) async {
    bool? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: EventPerformerRequestCard(
              request: requestCardFixture(),
              processing: false,
              onShowOnProfileChanged: (value) => changed = value,
              onAccept: () {},
              onReject: () {},
            ),
          ),
        ),
      ),
    );
    final checkbox = find.byType(CheckboxListTile);
    expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
    expect(changed, isTrue);
    expect(tester.widget<CheckboxListTile>(checkbox).value, isFalse);
    expect(find.text('Bu etkinliği profilimde de göster'), findsOneWidget);
  });

  for (final band in [false, true]) {
    for (final width in [320.0, 390.0]) {
      testWidgets(
        'permission rows align with a compact accessible checkbox: band=$band width=$width',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var changed = 0;
          final request = requestCardFixture(band: band);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: EventPerformerRequestCard(
                    request: request,
                    processing: false,
                    onAccept: () {},
                    onReject: () {},
                    onShowOnProfileChanged: (_) => changed++,
                  ),
                ),
              ),
            ),
          );
          final checkbox = find.byType(CheckboxListTile);
          final checkboxWidget = tester.widget<CheckboxListTile>(checkbox);
          final label = find.byWidget(checkboxWidget.title!);
          final control = find.descendant(
            of: checkbox,
            matching: find.byType(Checkbox),
          );
          final purpose = find.text(request.purposeExplanation);
          final summary = find.text(request.calendarVisibilityExplanation);
          final help = find.byKey(
            const Key('event-calendar-visibility-help-preview'),
          );
          expect(tester.getSize(checkbox).height, greaterThanOrEqualTo(48));
          expect(
            tester.getRect(label).left - tester.getRect(control).right,
            closeTo(8, .01),
          );
          expect(
            tester.getRect(label).left,
            closeTo(tester.getRect(purpose).left, .01),
          );
          expect(summary, findsNothing);
          expect(
            tester.getRect(help).left,
            greaterThanOrEqualTo(tester.getRect(checkbox).right),
          );
          expect(tester.getSize(help).height, greaterThanOrEqualTo(48));
          expect(find.text('Detaylar için dokun'), findsNothing);
          await tester.ensureVisible(help);
          await tester.pumpAndSettle();
          await tester.tap(help);
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('event-calendar-visibility-help-dialog')),
            findsOneWidget,
          );
          expect(
            find.byKey(const Key('event-calendar-visibility-notice')),
            findsOneWidget,
          );
          expect(changed, 0);
          final dismiss = find.byKey(
            const Key('event-calendar-visibility-help-dismiss'),
          );
          await tester.ensureVisible(dismiss);
          await tester.pumpAndSettle();
          await tester.tap(dismiss);
          await tester.pumpAndSettle();
          await tester.ensureVisible(checkbox);
          await tester.pumpAndSettle();
          await tester.tap(label);
          await tester.pump();
          expect(changed, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'legacy response disables publication and approval but permits rejection',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EventPerformerRequestCard(
                request: requestCardFixture(profileCalendarApproved: null),
                processing: false,
                onShowOnProfileChanged: (_) => calls++,
                onAccept: () => calls++,
                onReject: () => calls++,
              ),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      expect(
        tester
            .widget<GradientOutlineButton>(find.byType(GradientOutlineButton))
            .onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
      expect(find.textContaining('Güvenli onay için'), findsOneWidget);
      expect(calls, 0);
    },
  );
}

EventPerformerRequest requestCardFixture({
  bool band = false,
  bool longNames = false,
  String? posterImage,
  bool? profileCalendarApproved = false,
}) => EventPerformerRequest(
  requestId: 'preview',
  posterImage: posterImage,
  eventId: 'event',
  eventTitle: longNames
      ? 'Şahbaz ile Ankara Açık Hava Sahnesinde Çok Özel Akustik Gece'
      : 'Akustik Gece',
  eventDate: DateTime(2026, 9, 23),
  startTime: '20:00:00',
  endTime: '22:00:00',
  venueId: 'venue',
  venueName: longNames
      ? 'SoundConnect Ankara Canlı Müzik ve Performans Sahnesi'
      : 'soundconnectankara',
  venueProfilePictureUrl: null,
  targetType: band
      ? EventPerformerTargetType.band
      : EventPerformerTargetType.musician,
  targetId: 'profile',
  musicianProfileId: band ? null : 'profile',
  bandId: band ? 'profile' : null,
  performerName: band ? 'Şahbaz ve Sahne Arkadaşları' : 'bugrasahin',
  status: EventPerformerRequestStatus.pending,
  profileCalendarApproved: profileCalendarApproved,
  createdAt: DateTime(2026, 9, 5),
  decidedAt: null,
);
