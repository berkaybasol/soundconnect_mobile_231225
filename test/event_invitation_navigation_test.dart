import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_invitation_navigation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_invitation_navigation_fakes.dart';

void main() {
  late InvitationSession session;
  late InvitationCalendar personal;
  late InvitationCalendar band;
  late InvitationBands bands;
  late InvitationProfileRepository profiles;
  late InvitationRequests requests;

  setUp(() {
    session = InvitationSession();
    personal = InvitationCalendar();
    band = InvitationCalendar();
    bands = InvitationBands();
    profiles = InvitationProfileRepository();
    requests = InvitationRequests();
  });
  tearDown(() async {
    session.dispose();
    await personal.dispose();
    await band.dispose();
  });

  Future<void> launch(
    WidgetTester tester, {
    EventPerformerTargetType? type = EventPerformerTargetType.musician,
    String? id = 'musician-1',
    GlobalKey<NavigatorState>? navigatorKey,
    bool settle = true,
    bool doubleTap = false,
  }) async {
    final dependencies = EventInvitationNavigationDependencies(
      sessionKeyProvider: () => session.userId,
      sessionChanges: session,
      loadMyProfile: profiles.getMyProfile,
      loadBand: bands.getBandById,
      requests: requests,
    );
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(
                openEventInvitations(
                  context,
                  targetType: type,
                  targetId: id,
                  dependencies: dependencies,
                ),
              ),
              child: const Text('Open invitations'),
            ),
          ),
        ),
      ),
    );
    final action = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Open invitations'))
        .onPressed!;
    action();
    if (doubleTap) action();
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  for (final enabled in [false, true]) {
    testWidgets(
      'personal invitation access is independent of calendar: $enabled',
      (tester) async {
        personal.visible = enabled;
        await launch(tester);
        expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
        expect(requests.targetType, EventPerformerTargetType.musician);
        expect(requests.targetId, 'musician-1');
        expect(requests.reads, 1);
        expect(personal.reads, 0);
        expect(personal.writes, 0);
        expect(bands.reads, 0);
        expect(find.text('Haftalık takvimini aç'), findsNothing);
      },
    );
    testWidgets(
      'band invitation access is independent of both calendars: $enabled',
      (tester) async {
        band.visible = enabled;
        personal.visible = !enabled;
        await launch(tester, type: EventPerformerTargetType.band, id: 'band-1');
        expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
        expect(requests.targetType, EventPerformerTargetType.band);
        expect(requests.targetId, 'band-1');
        expect(bands.ids, ['band-1']);
        expect(profiles.reads, 0);
        expect(personal.reads + band.reads + personal.writes + band.writes, 0);
      },
    );
  }

  testWidgets('legacy entry resolves personal profile, not aggregate bands', (
    tester,
  ) async {
    await launch(tester, type: null, id: null);
    expect(requests.targetType, EventPerformerTargetType.musician);
    expect(requests.targetId, 'musician-1');
    expect(bands.reads, 0);
  });

  testWidgets('wrong explicit musician identity fails closed before inbox', (
    tester,
  ) async {
    await launch(tester, id: 'other-musician');
    expect(
      find.byKey(const Key('event-invitations-unavailable')),
      findsOneWidget,
    );
    expect(requests.reads, 0);
  });

  for (final role in ['MEMBER', 'MANAGER']) {
    testWidgets('band $role cannot open founder invitations', (tester) async {
      bands.read = (_) async => Result.success(invitationBand(role: role));
      await launch(tester, type: EventPerformerTargetType.band, id: 'band-1');
      expect(
        find.byKey(const Key('event-invitations-unavailable')),
        findsOneWidget,
      );
      expect(requests.reads, 0);
    });
  }

  testWidgets('inactive founder cannot open invitations', (tester) async {
    bands.read = (_) async => Result.success(invitationBand(status: 'LEFT'));
    await launch(tester, type: EventPerformerTargetType.band, id: 'band-1');
    expect(requests.reads, 0);
  });

  testWidgets('band identity mismatch never falls back to personal inbox', (
    tester,
  ) async {
    bands.read = (_) async => Result.success(invitationBand(id: 'other'));
    await launch(tester, type: EventPerformerTargetType.band, id: 'band-1');
    expect(requests.reads, 0);
    expect(profiles.reads, 0);
  });

  testWidgets('malformed scope is rejected before any fetch', (tester) async {
    await launch(tester, type: EventPerformerTargetType.band, id: null);
    expect(requests.reads + bands.reads + profiles.reads, 0);
  });

  testWidgets(
    'profile load failure can be retried without a calendar dependency',
    (tester) async {
      profiles.read = () async =>
          const Result.failure(AppError(code: 'offline', message: 'offline'));
      await launch(tester);
      expect(requests.reads, 0);
      profiles.read = null;
      await tester.tap(find.byKey(const Key('event-invitations-retry')));
      await tester.pumpAndSettle();
      expect(requests.reads, 1);
      expect(personal.reads, 0);
    },
  );

  testWidgets('duplicate entry taps mount only one inbox', (tester) async {
    await launch(tester, doubleTap: true);
    expect(profiles.reads, 1);
    expect(requests.reads, 1);
  });

  testWidgets('session change during preflight discards response', (
    tester,
  ) async {
    final pending = Completer<Result<MusicianProfile>>();
    profiles.read = () => pending.future;
    await launch(tester, settle: false);
    session.switchTo('different-owner');
    pending.complete(const Result.success(invitationProfile));
    await tester.pumpAndSettle();
    expect(requests.reads, 0);
    expect(find.byType(EventPerformerRequestsScreen), findsNothing);
  });

  testWidgets('calendar changes never close or reset the invitation inbox', (
    tester,
  ) async {
    await launch(tester);
    personal.invalidate();
    band.invalidate();
    await tester.pumpAndSettle();
    expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
    expect(requests.reads, 1);
  });

  testWidgets(
    'logout removes only owned inbox, preserving newer unrelated route',
    (tester) async {
      final key = GlobalKey<NavigatorState>();
      await launch(tester, navigatorKey: key);
      unawaited(
        key.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Unrelated route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      session.switchTo(null);
      await tester.pumpAndSettle();
      expect(find.text('Unrelated route'), findsOneWidget);
      expect(
        find.byType(EventPerformerRequestsScreen, skipOffstage: false),
        findsNothing,
      );
      expect(requests.accepts + requests.rejects, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('resume rechecks band founder authority without reading master', (
    tester,
  ) async {
    await launch(tester, type: EventPerformerTargetType.band, id: 'band-1');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    bands.read = (_) async => Result.success(invitationBand(role: 'MEMBER'));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(EventPerformerRequestsScreen), findsNothing);
    expect(
      find.byKey(const Key('event-invitations-unavailable')),
      findsOneWidget,
    );
    expect(personal.reads + band.reads, 0);
  });

  testWidgets(
    'stale resume result cannot override a newer authority rejection',
    (tester) async {
      await launch(tester, type: EventPerformerTargetType.band, id: 'band-1');
      final pending = Completer<Result<BandProfile>>();
      bands.read = (_) => pending.future;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      bands.read = (_) async => Result.success(invitationBand(role: 'MEMBER'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      pending.complete(Result.success(invitationBand()));
      await tester.pumpAndSettle();
      expect(find.byType(EventPerformerRequestsScreen), findsNothing);
      expect(requests.reads, 1);
    },
  );

  testWidgets('repeated dialog callbacks cannot pop the origin route', (
    tester,
  ) async {
    profiles.read = () async =>
        const Result.failure(AppError(code: 'offline', message: 'offline'));
    await launch(tester);
    final retry = tester
        .widget<GradientOutlineButton>(
          find.byKey(const Key('event-invitations-retry')),
        )
        .onPressed!;
    profiles.read = null;
    retry();
    retry();
    await tester.pumpAndSettle();
    expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
    expect(requests.reads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'logout disposes only the owned reject dialog without a decision',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      requests.items = [
        EventPerformerRequest(
          requestId: 'request-1',
          eventId: 'event-1',
          eventTitle: 'Test event',
          eventDate: DateTime(2026, 9, 6),
          startTime: '20:00',
          endTime: '22:00',
          venueId: 'venue-1',
          venueName: 'Venue',
          venueProfilePictureUrl: null,
          targetType: EventPerformerTargetType.musician,
          targetId: 'musician-1',
          musicianProfileId: 'musician-1',
          bandId: null,
          performerName: 'Musician',
          status: EventPerformerRequestStatus.pending,
          profileCalendarApproved: false,
          decisionAllowed: true,
          canReconsider: false,
          expired: false,
          serverNow: DateTime.utc(2026, 9, 6),
          eventStartsAt: DateTime.utc(2026, 9, 8, 18),
          createdAt: null,
          decidedAt: null,
        ),
      ];
      await launch(tester);
      final reject = find.byKey(const Key('reject-event-request-request-1'));
      await tester.ensureVisible(reject);
      await tester.pumpAndSettle();
      await tester.tap(reject);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('confirm-reject-request-1')), findsOneWidget);
      session.switchTo(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('confirm-reject-request-1')), findsNothing);
      expect(requests.accepts + requests.rejects, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
