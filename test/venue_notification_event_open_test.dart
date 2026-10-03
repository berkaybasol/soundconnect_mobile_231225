import 'support/notification_direct_test_host.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_direct_open.dart';
import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/core/push/push_provider.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/models/app_notification_model.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/data/notification_target_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/entities/app_notification.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/domain/notification_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/cubit/notification_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/notification_target_read.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/notification_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/notification/presentation/screens/venue_notification_open_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_performer_request.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/event_plan.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_owner_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_performer_request_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/event_plan_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_performer_requests_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_plan_performer_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/venue_event_plan_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/weekly_event_detail_screen.dart';

import 'support/event_audience_fakes.dart';
import 'support/event_invitation_navigation_fakes.dart' show InvitationRequests;

const _notification = '60000000-0000-4000-8000-000000000001';
const _other = '60000000-0000-4000-8000-000000000002';
const _sibling = '60000000-0000-4000-8000-000000000003';
const _user = '70000000-0000-4000-8000-000000000001';
const _venue = '80000000-0000-4000-8000-000000000001';
const _musician = '90000000-0000-4000-8000-000000000001';
const _event = 'a0000000-0000-4000-8000-000000000001';
const _plan = 'b0000000-0000-4000-8000-000000000001';
const _requested = 'EVENT_PERFORMER_APPROVAL_REQUESTED';
const _approved = 'EVENT_PERFORMER_APPROVED';
const _rejected = 'EVENT_PERFORMER_REJECTED';
const _missing = AppError(code: 'NOT_FOUND', message: 'Unavailable');
const _retry = 'Tekrar dene';

void main() {
  late _Fixture f;
  setUp(() async {
    await serviceLocator.reset();
    f = _Fixture();
  });
  tearDown(() async {
    await f.dispose();
    await serviceLocator.reset();
  });

  testWidgets(
    'exact target absent: unrelated performer request must not ACK notification',
    (tester) async {
      const missingRequest = 'c0000000-0000-4000-8000-000000000001';
      const unrelatedRequest = 'c0000000-0000-4000-8000-000000000002';
      f.requests.items = [
        const EventPerformerRequest(
          requestId: unrelatedRequest,
          eventId: _other,
          eventTitle: 'Unrelated invitation',
          eventDate: null,
          startTime: null,
          endTime: null,
          venueId: _venue,
          venueName: 'Current venue',
          venueProfilePictureUrl: null,
          targetType: EventPerformerTargetType.musician,
          targetId: _musician,
          musicianProfileId: _musician,
          bandId: null,
          performerName: 'Current performer',
          status: EventPerformerRequestStatus.pending,
          createdAt: null,
          decidedAt: null,
        ),
      ];
      await f.mount(
        tester,
        type: _requested,
        initialLifecycle: AppLifecycleState.inactive,
      );
      (f.api.dto['payload'] as Map)['requestId'] = missingRequest;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(f.api.gets, 1);
      expect(f.requests.reads, 1);
      expect(f.requests.items.map((request) => request.requestId), [
        unrelatedRequest,
      ]);
      expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
      expect(
        find.byKey(const Key('event-approval-card-$unrelatedRequest')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('event-approval-card-$missingRequest')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      f.expectNoRead(tester);
      expect(f.cubit.state.unreadCount, 2);
    },
  );

  testWidgets(
    'exact target absent: unrelated performer plan must not ACK notification',
    (tester) async {
      f.plans.performerListItems = [
        f.plans.valueFor(id: _other, title: 'Unrelated plan'),
      ];
      await f.mount(tester, type: _requested, plan: true);
      await tester.pumpAndSettle();

      // The exact preflight succeeds; only a different plan reaches the list.
      expect(f.plans.performerReads, [_plan]);
      expect(f.plans.performerLists, [_musician]);
      expect(f.plans.performerListItems!.map((plan) => plan.id), [_other]);
      expect(find.byType(EventPlanPerformerScreen), findsOneWidget);
      expect(find.text('Unrelated plan'), findsOneWidget);
      expect(find.text('Current plan'), findsNothing);
      expect(tester.takeException(), isNull);
      f.expectNoRead(tester);
      expect(f.cubit.state.unreadCount, 2);
    },
  );

  for (final replaceSession in [false, true]) {
    testWidgets(
      'exact plan on next page waits for its fresh visible row, session replaced=$replaceSession',
      (tester) async {
        f.plans.performerPages = {
          0: [f.plans.valueFor(id: _other, title: 'Unrelated plan')],
          1: [f.plans.value],
        };
        await f.mount(tester, type: _requested, plan: true);
        await tester.pumpAndSettle();
        f.expectNoRead(tester);
        expect(f.plans.performerListPages, [0]);

        f.plans.performerListPending = Completer<void>();
        await tester.ensureVisible(find.text('Sonraki'));
        await tester.tap(find.text('Sonraki'));
        await tester.pump();
        expect(f.plans.performerListPages, [0, 1]);
        f.expectNoRead(tester);
        if (replaceSession) {
          f.sessions.replace(
            audienceSession(user: _other, role: 'ROLE_MUSICIAN'),
          );
        }
        f.plans.performerListPending!.complete();
        await tester.pumpAndSettle();
        if (replaceSession) {
          f.expectNoRead(tester);
          expect(find.text('Current plan'), findsNothing);
        } else {
          await tester.ensureVisible(find.text('Current plan'));
          await tester.pumpAndSettle();
          f.expectOneRead(tester);
        }
        expect(f.plans.performerReads, [_plan]);
        expect(f.api.gets, 1);
      },
    );
  }

  testWidgets('exact plan below the viewport waits until scrolled into view', (
    tester,
  ) async {
    f.plans.performerListItems = [
      for (var i = 0; i < 8; i++)
        f.plans.valueFor(id: 'unrelated-$i', title: 'Unrelated plan $i'),
      f.plans.value,
    ];
    await f.mount(tester, type: _requested, plan: true);
    await tester.pumpAndSettle();
    f.expectNoRead(tester);
    await tester.scrollUntilVisible(find.text('Current plan'), 500);
    await tester.pumpAndSettle();
    f.expectOneRead(tester);
    expect(f.plans.performerLists, [_musician]);
    expect(f.plans.performerReads, [_plan]);
  });

  for (final failFirst in [false, true]) {
    testWidgets(
      'invitation reentry keeps old list and target-only read, GET failure=$failFirst',
      (tester) async {
        await f.mount(tester, type: _requested);
        await tester.pumpAndSettle();
        f.expectOneRead(tester);
        final oldRoute = ModalRoute.of(
          tester.element(find.byType(EventPerformerRequestsScreen)),
        )!;
        await f.prepareSecond();
        f.api.offline = failFirst;
        f.pushSecond();
        await tester.pumpAndSettle();
        if (failFirst) {
          expect(f.api.gets, 2);
          f.expectSecondUnread();
          f.api.offline = false;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(f.api.gets, 2);
          f.expectSecondUnread();
          final retry = tester
              .widget<SnackBarAction>(find.byType(SnackBarAction))
              .onPressed;
          f.api.getPending = Completer<void>();
          retry();
          retry();
          await tester.pump();
          expect(f.api.gets, 3);
          f.api.getPending!.complete();
          await tester.pumpAndSettle();
        }
        expect(oldRoute.isActive, isTrue);
        expect(oldRoute.isCurrent, isFalse);
        expect(
          find.byType(EventPerformerRequestsScreen, skipOffstage: false),
          findsNWidgets(2),
        );
        expect(f.requests.reads, greaterThanOrEqualTo(2));
        expect(f.api.gets, failFirst ? 3 : 2);
        f.expectSecondRead(tester);
        f.navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(oldRoute.isCurrent, isTrue);
        f.expectSecondRead(tester); // Returning never re-ACKs the old ticket.
      },
    );
  }

  for (final mismatch in ['profile', 'payload', 'owner']) {
    testWidgets(
      'invitation reentry rejects new $mismatch despite old successful target',
      (tester) async {
        await f.mount(tester, type: _requested);
        await tester.pumpAndSettle();
        await f.prepareSecond();
        final payload = Map<String, dynamic>.from(f.api.dto['payload'] as Map);
        if (mismatch == 'profile') {
          payload['musicianProfileId'] = _other;
          payload['targetId'] = _other;
        } else if (mismatch == 'payload') {
          payload['targetType'] = 'BAND';
        } else {
          f.profiles.reject = true;
        }
        f.api.dto['payload'] = payload;
        f.pushSecond();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        if (mismatch != 'payload') {
          expect(
            find.byKey(const Key('event-invitations-unavailable')),
            findsNothing,
          );
        }
        await tester.pumpAndSettle();
        f.expectSecondUnread();
        expect(f.requests.reads, 1);
        expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
        expect(
          find.byType(EventPerformerRequestsScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('invitation reentry resolves a plan destination independently', (
    tester,
  ) async {
    await f.mount(tester, type: _requested);
    await tester.pumpAndSettle();
    await f.prepareSecond();
    f.api.dto['payload'] = {
      ...Map<String, dynamic>.from(f.api.dto['payload'] as Map),
      'module': 'EVENT_PLAN',
      'planId': _plan,
    };
    f.pushSecond();
    await tester.pumpAndSettle();
    expect(find.byType(EventPlanPerformerScreen), findsOneWidget);
    expect(
      find.byType(EventPerformerRequestsScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(f.plans.performerReads, [_plan]);
    expect(f.plans.performerLists, [_musician]);
    f.expectSecondRead(tester, plan: true);
  });

  for (final hiding in ['dialog', 'background', 'removed', 'token', 'logout']) {
    testWidgets('invitation reentry content under $hiding cannot ACK early', (
      tester,
    ) async {
      await f.mount(tester, type: _requested);
      await tester.pumpAndSettle();
      await f.prepareSecond();
      final pending = Completer<void>();
      f.requests.pending = pending;
      f.pushSecond();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(f.requests.reads, 2);
      f.expectSecondUnread();
      if (hiding == 'dialog') {
        await f.cover(tester, dialog: true);
      } else if (hiding == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else if (hiding == 'removed') {
        f.navigator.currentState!.pop();
      } else {
        f.sessions.replace(
          hiding == 'logout'
              ? const AuthSession.guest()
              : audienceSession(
                  user: _user,
                  role: 'ROLE_MUSICIAN',
                  token: 'new-token',
                ),
        );
      }
      pending.complete();
      await tester.pumpAndSettle();
      expect(f.api.acks, [_notification]);
      expect(
        f.notifications.items.singleWhere((n) => n.id == _other).read,
        isFalse,
      );
      expect(f.comparisons, 1);
      if (hiding == 'dialog' || hiding == 'background') {
        await f.reveal(tester, hiding);
        f.expectSecondRead(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'second invitation ACK recovery never consumes first or sibling',
    (tester) async {
      await f.mount(tester, type: _requested);
      await tester.pumpAndSettle();
      await f.prepareSecond();
      f.api.failAck = true;
      f.pushSecond();
      await tester.pumpAndSettle();
      expect(f.api.acks, [_notification, _other]);
      expect(f.cubit.state.unreadCount, 2);
      expect(find.text(_retry), findsOneWidget);
      await f.cover(tester);
      f.api.failAck = false;
      f.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(f.api.acks, [_notification, _other]);
      final lists = f.requests.reads;
      final retry = tester
          .widget<SnackBarAction>(find.byType(SnackBarAction))
          .onPressed;
      f.api.ackPending = Completer<void>();
      retry();
      retry();
      await tester.pump();
      expect(f.api.acks, [_notification, _other, _other]);
      f.api.ackPending!.complete();
      await tester.pumpAndSettle();
      expect(f.api.gets, 2);
      expect(f.requests.reads, lists);
      f.expectSecondRead(tester, secondAttempts: 2);
    },
  );

  for (final dialog in [false, true]) {
    testWidgets('unattempted entry returns from cover dialog=$dialog once', (
      tester,
    ) async {
      await f.mount(
        tester,
        type: _requested,
        initialLifecycle: AppLifecycleState.inactive,
      );
      await f.cover(tester, dialog: dialog);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 400));
      expect(f.api.gets, 0);
      f.expectNoRead(tester);
      f.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(f.api.gets, 1);
      expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
      f.expectOneRead(tester);
    });
  }

  testWidgets('nested covers returning in background still wait for resume', (
    tester,
  ) async {
    await f.mount(
      tester,
      type: _requested,
      initialLifecycle: AppLifecycleState.inactive,
    );
    await f.cover(tester);
    await f.cover(tester, dialog: true);
    f.navigator.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 400));
    expect(f.api.gets, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    f.navigator.currentState!.pop();
    await tester.pump(const Duration(milliseconds: 400));
    expect(f.api.gets, 0);
    f.expectNoRead(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(f.api.gets, 1);
    f.expectOneRead(tester);
  });

  for (final fails in [false, true]) {
    for (final completesCovered in [false, true]) {
      testWidgets(
        'covered GET fails=$fails completesCovered=$completesCovered recovers without auto retry',
        (tester) async {
          f.api.getPending = Completer<void>();
          await f.mount(tester, type: _requested);
          await tester.pump();
          expect(f.api.gets, 1);
          await f.cover(tester);
          f.api.offline = fails;
          if (completesCovered) {
            f.api.getPending!.complete();
            await tester.pump(const Duration(milliseconds: 400));
            expect(f.requests.targetId, isNull);
            f.expectNoRead(tester);
          }
          f.navigator.currentState!.pop();
          await tester.pump(const Duration(milliseconds: 400));
          expect(f.api.gets, 1);
          f.expectNoRead(tester);
          if (!completesCovered) {
            // Returning while the original request is alive cannot start a
            // second request or offer a clickable retry for that live request.
            expect(find.text('Tekrar dene'), findsNothing);
            await f.cover(tester, dialog: true);
            f.navigator.currentState!.pop();
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
            await tester.pump(const Duration(milliseconds: 400));
            expect(f.api.gets, 1);
            f.api.getPending!.complete();
            await tester.pumpAndSettle();
          }
          if (completesCovered || fails) {
            await tester.pumpAndSettle();
            expect(find.text('Tekrar dene'), findsOneWidget);
            expect(find.byType(CircularProgressIndicator), findsNothing);
            f.expectNoRead(tester);
            f.api.offline = false;
            for (var turn = 0; turn < 2; turn++) {
              await f.cover(tester, dialog: turn == 1);
              f.navigator.currentState!.pop();
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.inactive,
              );
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.resumed,
              );
              await tester.pumpAndSettle();
              expect(f.api.gets, 1);
              f.expectNoRead(tester);
            }
            await tester.tap(find.text('Tekrar dene'));
            await tester.pumpAndSettle();
            expect(f.api.gets, 2);
          } else {
            expect(f.api.gets, 1);
          }
          expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
          f.expectOneRead(tester);
        },
      );
    }
  }

  testWidgets('covered destination lookup also exposes explicit retry', (
    tester,
  ) async {
    f.events.pending = Completer<Result<VenueEventDetail>>();
    await f.mount(tester, type: _approved);
    await tester.pump();
    expect(f.api.gets, 1);
    expect(f.events.readIds, [_event]);
    await f.cover(tester);
    f.events.pending!.complete(Result.success(f.events.detail));
    await tester.pump(const Duration(milliseconds: 400));
    f.expectNoRead(tester);
    f.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(f.api.gets, 1);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
    expect(f.api.gets, 2);
    f.expectOneRead(tester);
  });

  for (final started in [false, true]) {
    for (final invalidation in ['logout', 'account', 'token', 'removed']) {
      testWidgets(
        'covered entry started=$started cannot revive after $invalidation',
        (tester) async {
          if (started) f.api.getPending = Completer<void>();
          await f.mount(
            tester,
            type: _requested,
            initialLifecycle: started
                ? AppLifecycleState.resumed
                : AppLifecycleState.inactive,
          );
          await tester.pump();
          final opener = NotificationDirectOpen.routeOf(
            tester.element(
              find.byType(VenueNotificationOpenScreen, skipOffstage: false),
            ),
          )!;
          await f.cover(tester);
          if (invalidation == 'removed') {
            f.navigator.currentState!.removeRoute(opener);
          } else if (invalidation == 'logout') {
            f.sessions.replace(const AuthSession.guest());
          } else {
            f.sessions.replace(
              audienceSession(
                user: invalidation == 'account' ? _other : _user,
                token: 'replacement',
                role: 'ROLE_MUSICIAN',
              ),
            );
          }
          await tester.pump(const Duration(milliseconds: 400));
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          if (invalidation != 'removed') f.navigator.currentState!.pop();
          await tester.pump(const Duration(milliseconds: 400));
          f.api.getPending?.complete();
          await tester.pump(const Duration(milliseconds: 400));
          // Exercise later observer callbacks after removal/invalidation too.
          await f.cover(tester, dialog: true);
          f.navigator.currentState!.pop();
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pump(const Duration(milliseconds: 400));
          if (find.text('Tekrar dene').evaluate().isNotEmpty) {
            await tester.tap(find.text('Tekrar dene'));
            await tester.pump(const Duration(milliseconds: 400));
          }
          expect(f.api.gets, started ? 1 : 0);
          expect(f.requests.targetId, isNull);
          f.expectNoRead(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('queued cover return cannot open after immediate removal', (
    tester,
  ) async {
    await f.mount(
      tester,
      type: _requested,
      initialLifecycle: AppLifecycleState.inactive,
    );
    await f.cover(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    f.navigator.currentState!.pop();
    unawaited(
      f.navigator.currentState!.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Replacement')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(f.api.gets, 0);
    f.expectNoRead(tester);
    expect(tester.takeException(), isNull);
  });

  for (final lifecycle in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    testWidgets(
      'first native entry waits for ${lifecycle.name} before resolving',
      (tester) async {
        await f.mount(tester, type: _requested, initialLifecycle: lifecycle);
        await tester.pump(const Duration(milliseconds: 350));
        expect(f.api.gets, 0);
        expect(f.requests.targetId, isNull);
        expect(find.text('Tekrar dene'), findsNothing);
        f.expectNoRead(tester);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
        expect(f.api.gets, 1);
        f.expectOneRead(tester);
      },
    );
  }

  for (final invalidation in [
    'logout',
    'account',
    'token',
    'covered',
    'removed',
  ]) {
    testWidgets('deferred first entry cannot cross $invalidation', (
      tester,
    ) async {
      await f.mount(
        tester,
        type: _requested,
        initialLifecycle: AppLifecycleState.inactive,
      );
      if (invalidation == 'logout') {
        f.sessions.replace(const AuthSession.guest());
      } else if (invalidation == 'account' || invalidation == 'token') {
        f.sessions.replace(
          audienceSession(
            user: invalidation == 'account' ? _other : _user,
            token: 'changed',
            role: 'ROLE_MUSICIAN',
          ),
        );
      } else {
        final route = MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Cover')),
        );
        if (invalidation == 'removed') {
          unawaited(f.navigator.currentState!.pushReplacement(route));
        } else {
          unawaited(f.navigator.currentState!.push(route));
        }
        await tester.pump(const Duration(milliseconds: 350));
      }
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 350));
      expect(f.api.gets, 0);
      expect(f.requests.targetId, isNull);
      f.expectNoRead(tester);
    });
  }

  testWidgets('deferred first GET failure needs explicit retry after resume', (
    tester,
  ) async {
    f.api.offline = true;
    await f.mount(
      tester,
      type: _requested,
      initialLifecycle: AppLifecycleState.inactive,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(f.api.gets, 1);
    expect(find.text('Tekrar dene'), findsOneWidget);
    f.api.offline = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(f.api.gets, 1);
    f.expectNoRead(tester);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(f.api.gets, 2);
    f.expectOneRead(tester);
  });

  testWidgets('foreground lost during GET does not navigate or auto retry', (
    tester,
  ) async {
    f.api.getPending = Completer<void>();
    await f.mount(tester, type: _requested);
    await tester.pump();
    expect(f.api.gets, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    f.api.getPending!.complete();
    await tester.pump(const Duration(milliseconds: 350));
    expect(f.requests.targetId, isNull);
    f.expectNoRead(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(f.api.gets, 1);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    f.expectOneRead(tester);
  });

  testWidgets(
    'repeated resume during first GET cannot duplicate entry or read',
    (tester) async {
      f.api.getPending = Completer<void>();
      await f.mount(
        tester,
        type: _requested,
        initialLifecycle: AppLifecycleState.inactive,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(f.api.gets, 1);
      f.api.getPending!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
      f.expectOneRead(tester);
    },
  );

  for (final purpose in ['PERFORMER_CONSENT', 'PROFILE_VISIBILITY']) {
    testWidgets(
      'external $purpose request opens current scoped invitations and reads only its row',
      (tester) async {
        await f.mount(tester, type: _requested, purpose: purpose);
        await tester.pumpAndSettle();
        final screen = tester.widget<EventPerformerRequestsScreen>(
          find.byType(EventPerformerRequestsScreen),
        );
        expect(screen.targetType, EventPerformerTargetType.musician);
        expect(screen.targetId, _musician);
        expect(f.requests.targetId, _musician);
        expect(
          f.events.readIds,
          isEmpty,
        ); // No invented single-event decision route.
        f.expectOneRead(tester);
      },
    );
    for (final type in [_approved, _rejected]) {
      testWidgets(
        'external $purpose $type uses live event identity and reads only its row',
        (tester) async {
          await f.mount(tester, type: type, purpose: purpose);
          await tester.pumpAndSettle();
          final screen = tester.widget<WeeklyEventDetailScreen>(
            find.byType(WeeklyEventDetailScreen),
          );
          expect(screen.event.id, _event);
          expect(screen.event.title, 'Current event');
          expect(screen.event.artistProfileId, isNull);
          expect(screen.event.bandProfileId, isNull);
          expect(screen.event.description, 'Current authored description');
          expect(f.events.readIds, isNotEmpty);
          expect(f.events.readIds.every((id) => id == _event), isTrue);
          f.expectOneRead(tester);
        },
      );
    }
  }

  testWidgets(
    'external plan request resolves current plan then opens only its performer scope',
    (tester) async {
      await f.mount(tester, type: _requested, plan: true);
      await tester.pumpAndSettle();
      final screen = tester.widget<EventPlanPerformerScreen>(
        find.byType(EventPlanPerformerScreen),
      );
      expect(screen.targetId, _musician);
      expect(screen.targetType, EventPerformerTargetType.musician);
      expect(f.plans.performerReads, [_plan]);
      expect(f.plans.performerLists, [_musician]);
      expect(find.byType(VenueEventPlanScreen), findsNothing);
      f.expectOneRead(tester);
    },
  );

  for (final choice in [
    (type: _approved, action: 'ACCEPT', consent: 'ACCEPTED'),
    (type: _rejected, action: 'REJECT', consent: 'REJECTED'),
    (type: _rejected, action: 'WITHDRAW', consent: 'WITHDRAWN'),
  ]) {
    testWidgets(
      'external plan ${choice.action} opens exact current owner plan and reads only its row',
      (tester) async {
        f.plans.consent = choice.consent;
        await f.mount(
          tester,
          type: choice.type,
          plan: true,
          action: choice.action,
        );
        await tester.pumpAndSettle();
        final screen = tester.widget<VenueEventPlanScreen>(
          find.byType(VenueEventPlanScreen),
        );
        expect(screen.planId, _plan);
        expect(screen.ownerProfile.venueId, _venue);
        expect(f.plans.ownerReads, everyElement(_plan));
        expect(f.plans.occurrenceReads, [_plan]);
        expect(f.venues.readIds, [_venue]);
        expect(find.byType(EventPlanPerformerScreen), findsNothing);
        f.expectOneRead(tester);
      },
    );
  }

  for (final kind in ['event', 'owner-plan', 'performer-plan']) {
    testWidgets(
      'external missing current $kind never ACKs or falls back to inbox',
      (tester) async {
        f.events.missing = kind == 'event';
        f.plans.missing = kind != 'event';
        await f.mount(
          tester,
          type: kind == 'performer-plan' ? _requested : _approved,
          plan: kind != 'event',
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(VenueNotificationOpenScreen, skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('Tekrar dene'), findsOneWidget);
        f.expectNoRead(tester);
      },
    );
    testWidgets(
      'external session replacement during $kind preflight cannot navigate or ACK',
      (tester) async {
        if (kind == 'event') {
          f.events.pending = Completer<Result<VenueEventDetail>>();
        }
        if (kind != 'event') f.plans.pending = Completer<Result<EventPlan>>();
        await f.mount(
          tester,
          type: kind == 'performer-plan' ? _requested : _approved,
          plan: kind != 'event',
        );
        await tester.pump();
        f.sessions.replace(
          audienceSession(
            user: _user,
            token: 'replacement',
            role: 'ROLE_VENUE',
          ),
        );
        f.events.pending?.complete(Result.success(f.events.detail));
        f.plans.pending?.complete(Result.success(f.plans.value));
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(WeeklyEventDetailScreen), findsNothing);
        expect(find.byType(VenueEventPlanScreen), findsNothing);
        expect(find.byType(EventPlanPerformerScreen), findsNothing);
        expect(f.api.acks, isEmpty);
        expect(f.comparisons, 0);
      },
    );
  }

  testWidgets(
    'external plan request cannot reuse stale payload performer when live scope changed',
    (tester) async {
      f.plans.target = 'different-current-profile';
      await f.mount(tester, type: _requested, plan: true);
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.byKey(const Key('event-invitations-unavailable')),
        findsNothing,
      );
      expect(find.byType(EventPlanPerformerScreen), findsNothing);
      f.expectNoRead(tester);
    },
  );

  testWidgets(
    'external owner plan requires current matching venue ownership before ACK',
    (tester) async {
      f.venues.owner = 'different-current-owner';
      await f.mount(tester, type: _approved, plan: true);
      await tester.pumpAndSettle();
      expect(find.byType(VenueEventPlanScreen), findsNothing);
      f.expectNoRead(tester);
    },
  );

  testWidgets(
    'external offline lookup retry fetches fresh source and ACKs once',
    (tester) async {
      f.api.offline = true;
      await f.mount(tester, type: _approved);
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
      f.expectNoRead(tester);
      f.api.offline = false;
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(f.api.gets, 2);
      expect(find.byType(WeeklyEventDetailScreen), findsOneWidget);
      f.expectOneRead(tester);
    },
  );

  testWidgets(
    'external destination opens when ACK fails but neither row is projected read',
    (tester) async {
      f.api.failAck = true;
      await f.mount(tester, type: _approved, plan: true);
      await tester.pumpAndSettle();
      expect(find.byType(VenueEventPlanScreen), findsOneWidget);
      expect(f.api.acks, [_notification]);
      expect(f.notifications.items.every((row) => !row.read), isTrue);
      expect(f.cubit.state.items.every((row) => !row.read), isTrue);
      expect(f.cubit.state.unreadCount, 2);
      expect(f.comparisons, 0);
      expect(find.text(_retry), findsOneWidget);
    },
  );

  testWidgets(
    'destination loading and failed content never ACK route creation',
    (tester) async {
      f.plans.destinationPending = Completer<Result<EventPlan>>();
      await f.mount(tester, type: _approved, plan: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(VenueEventPlanScreen), findsOneWidget);
      expect(f.plans.ownerReads.length, 2);
      f.expectNoRead(tester);
      f.plans.destinationPending!.complete(const Result.failure(_missing));
      await tester.pumpAndSettle();
      f.expectNoRead(tester);
      expect(find.text(_retry), findsNothing);
    },
  );

  testWidgets('loaded destination waits for its visible transition frame', (
    tester,
  ) async {
    f.plans.destinationPending = Completer<Result<EventPlan>>();
    await f.mount(tester, type: _approved, plan: true);
    await tester.pump();
    f.plans.destinationPending!.complete(Result.success(f.plans.value));
    await tester.pump();
    f.expectNoRead(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    f.expectOneRead(tester);
  });

  testWidgets('empty invitation target remains unread', (tester) async {
    f.requests.items.clear();
    await f.mount(tester, type: _requested);
    await tester.pumpAndSettle();
    expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
    f.expectNoRead(tester);
  });

  for (final hiding in ['background', 'dialog']) {
    testWidgets('destination completes behind $hiding without early ACK', (
      tester,
    ) async {
      f.plans.destinationPending = Completer<Result<EventPlan>>();
      await f.mount(tester, type: _approved, plan: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // A pending spinner cannot settle. Suspend before resolving its content.
      if (hiding == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      } else {
        unawaited(
          showDialog<void>(
            context: f.navigator.currentContext!,
            builder: (_) => const AlertDialog(content: Text('Other dialog')),
          ),
        );
      }
      f.plans.destinationPending!.complete(Result.success(f.plans.value));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      f.expectNoRead(tester);
      await f.reveal(tester, hiding);
      f.expectOneRead(tester);
    });
  }

  testWidgets(
    'target reload invalidates pending ACK even after content returns',
    (tester) async {
      f.api.ackPending = Completer<void>();
      await f.mount(tester, type: _approved, plan: true);
      await tester.pumpAndSettle();
      expect(f.api.acks, [_notification]);
      f.plans.destinationPending = Completer<Result<EventPlan>>();
      await tester.tap(find.byTooltip('Planı yenile'));
      await tester.pump();
      f.plans.destinationPending!.complete(Result.success(f.plans.value));
      await tester.pumpAndSettle();
      f.api.ackPending!.complete();
      await tester.pumpAndSettle();
      expect(f.cubit.state.items.every((row) => !row.read), isTrue);
      expect(f.comparisons, 0);
      expect(f.api.acks.length, 1);
      await tester.tap(find.text(_retry));
      await tester.pumpAndSettle();
      f.expectOneRead(tester, attempts: 2);
    },
  );

  testWidgets(
    'late failure cannot put recovery on an unrelated replacement route',
    (tester) async {
      f.api.ackPending = Completer<void>();
      await f.mount(tester, type: _approved);
      await tester.pumpAndSettle();
      await f.hide(tester, 'removed');
      f.api.failAck = true;
      f.api.ackPending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Other destination'), findsOneWidget);
      expect(find.text(_retry), findsNothing);
      expect(f.api.acks, [_notification]);
      expect(f.cubit.state.items.every((row) => !row.read), isTrue);
      expect(f.cubit.state.unreadCount, 2);
      expect(f.comparisons, 0);
    },
  );

  for (final plan in [false, true]) {
    testWidgets(
      'ACK-only retry preserves destination and sibling, plan=$plan',
      (tester) async {
        f.api.failAck = true;
        await f.mount(tester, type: _approved, plan: plan);
        await tester.pumpAndSettle();
        expect(find.text(_retry), findsOneWidget);
        expect(f.api.acks, [_notification]);
        expect(f.cubit.state.unreadCount, 2);
        expect(f.comparisons, 0);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(seconds: 5));
        expect(f.api.acks.length, 1);
        // The destination's own resume refresh is independent of ACK recovery.
        final gets = f.api.gets;
        final eventReads = f.events.readIds.length;
        final planReads = f.plans.ownerReads.length;
        f.api.failAck = false;
        f.api.ackPending = Completer<void>();
        final retry = tester
            .widget<SnackBarAction>(find.byType(SnackBarAction))
            .onPressed;
        retry();
        retry();
        await tester.pump();
        expect(f.api.acks, [_notification, _notification]);
        expect(
          f.api.acks.length,
          2,
        ); // Explicit retry is single-flight while pending.
        expect(f.cubit.state.unreadCount, 2);
        f.api.ackPending!.complete();
        await tester.pumpAndSettle();
        f.expectOneRead(tester, attempts: 2);
        expect(find.text(_retry), findsNothing);
        expect(f.api.gets, gets);
        expect(f.events.readIds.length, eventReads);
        expect(f.plans.ownerReads.length, planReads);
        expect(
          find.byType(plan ? VenueEventPlanScreen : WeeklyEventDetailScreen),
          findsOneWidget,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(f.api.acks.length, 2);
      },
    );
  }

  testWidgets('a second ACK failure keeps the explicit recovery available', (
    tester,
  ) async {
    f.api.failAck = true;
    await f.mount(tester, type: _approved);
    await tester.pumpAndSettle();
    await tester.tap(find.text(_retry));
    await tester.pumpAndSettle();
    expect(f.api.acks.length, 2);
    expect(find.text(_retry), findsOneWidget);
    expect(f.cubit.state.items.every((row) => !row.read), isTrue);
    expect(f.cubit.state.unreadCount, 2);
    expect(f.comparisons, 0);
    f.api.failAck = false;
    await tester.tap(find.text(_retry));
    await tester.pumpAndSettle();
    f.expectOneRead(tester, attempts: 3);
  });

  for (final hiding in [
    'background',
    'dialog',
    'removed',
    'token',
    'logout',
    'account',
  ]) {
    testWidgets('late ACK after $hiding cannot project read or reconcile OS', (
      tester,
    ) async {
      f.api.ackPending = Completer<void>();
      await f.mount(tester, type: _approved, plan: true);
      await tester.pumpAndSettle();
      expect(f.api.acks, [_notification]);
      await f.hide(tester, hiding);
      if (hiding == 'background' || hiding == 'dialog') {
        await f.reveal(tester, hiding);
      }
      f.api.ackPending!.complete();
      await tester.pumpAndSettle();
      // A sent HTTP request can succeed remotely; the stale local projection is fenced.
      expect(f.api.acks.length, 1);
      expect(f.cubit.state.items.every((row) => !row.read), isTrue);
      expect(f.comparisons, 0);
      expect(f.notifications.broadMutations, 0);
      if (hiding == 'background' || hiding == 'dialog') {
        expect(f.cubit.state.unreadCount, 2);
        expect(find.text(_retry), findsOneWidget);
        await tester.tap(find.text(_retry));
        await tester.pumpAndSettle();
        f.expectOneRead(tester, attempts: 2);
      } else {
        expect(find.text(_retry), findsNothing);
      }
    });

    testWidgets('retry action captured before $hiding cannot send old ACK', (
      tester,
    ) async {
      f.api.failAck = true;
      await f.mount(tester, type: _approved, plan: true);
      await tester.pumpAndSettle();
      final retry = tester
          .widget<SnackBarAction>(find.byType(SnackBarAction))
          .onPressed;
      await f.hide(tester, hiding);
      retry();
      await tester.pumpAndSettle();
      if (hiding == 'background') {
        // Paused Flutter does not paint another frame: the previous widget tree
        // can remain inspectable, but its portal is hidden and action is fenced.
        expect(
          tester
              .widgetList<OverlayPortal>(find.byType(OverlayPortal))
              .every((portal) => !portal.controller.isShowing),
          isTrue,
        );
      } else {
        expect(find.text(_retry), findsNothing);
      }
      expect(f.api.acks.length, 1);
      expect(f.comparisons, 0);
      if (hiding == 'background' || hiding == 'dialog') {
        await f.reveal(tester, hiding);
        expect(f.api.acks.length, 1);
        expect(find.text(_retry), findsOneWidget);
      }
    });
  }
}

class _Fixture {
  final navigator = GlobalKey<NavigatorState>();
  final sessions = AudienceTestSessions(
    audienceSession(user: _user, role: 'ROLE_VENUE'),
  );
  final notifications = _Notifications();
  final realtime = _Realtime();
  final events = _Events();
  final plans = _Plans();
  final profiles = _Profiles();
  final venues = _Venues();
  final requests = _Requests()
    ..items = [
      const EventPerformerRequest(
        requestId: 'c0000000-0000-4000-8000-000000000003',
        eventId: _event,
        eventTitle: 'Current invitation',
        eventDate: null,
        startTime: null,
        endTime: null,
        venueId: _venue,
        venueName: 'Current venue',
        venueProfilePictureUrl: null,
        targetType: EventPerformerTargetType.musician,
        targetId: _musician,
        musicianProfileId: _musician,
        bandId: null,
        performerName: 'Current performer',
        status: EventPerformerRequestStatus.pending,
        createdAt: null,
        decidedAt: null,
      ),
    ];
  late final api = _Api(notifications);
  late final cubit = NotificationCubit(
    notifications,
    _Tokens(),
    sessions: sessions,
    realtimeClient: realtime,
    onDeliveryStateChanged: () async {
      comparisons++;
    },
  );
  int comparisons = 0;

  Future<void> prepareSecond() async {
    api.dto = {...api.dto, 'id': _other};
    notifications.items.add(
      AppNotificationModel.fromJson({...api.dto, 'id': _sibling}),
    );
    await cubit.refresh();
  }

  void pushSecond() {
    unawaited(
      NotificationDirectOpen.start(
        navigator.currentContext!,
        identity: _other,
        builder: (_) => const VenueNotificationOpenScreen(
          target: PushTarget(
            notificationId: _other,
            recipientId: _user,
            type: _requested,
          ),
        ),
      ),
    );
  }

  void expectSecondUnread() {
    expect(api.acks, [_notification]);
    expect(
      notifications.items.singleWhere((n) => n.id == _other).read,
      isFalse,
    );
    expect(
      notifications.items.singleWhere((n) => n.id == _sibling).read,
      isFalse,
    );
    expect(cubit.state.unreadCount, 2);
    expect(comparisons, 1);
  }

  void expectSecondRead(
    WidgetTester tester, {
    bool plan = false,
    int secondAttempts = 1,
  }) {
    expect(api.acks, [_notification, ...List.filled(secondAttempts, _other)]);
    for (final rows in [notifications.items, cubit.state.items]) {
      expect(rows.singleWhere((n) => n.id == _notification).read, isTrue);
      expect(rows.singleWhere((n) => n.id == _other).read, isTrue);
      expect(rows.singleWhere((n) => n.id == _sibling).read, isFalse);
    }
    expect(cubit.state.unreadCount, 1);
    expect(comparisons, 2);
    if (plan) {
      expect(find.byType(EventPlanPerformerScreen), findsOneWidget);
    } else {
      expect(find.byType(EventPerformerRequestsScreen), findsOneWidget);
    }
    expect(notifications.broadMutations, 0);
    expect(tester.takeException(), isNull);
  }

  Future<void> cover(WidgetTester tester, {bool dialog = false}) async {
    if (dialog) {
      unawaited(
        showDialog<void>(
          context: navigator.currentContext!,
          builder: (_) => const AlertDialog(content: Text('Temporary cover')),
        ),
      );
    } else {
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Temporary cover')),
          ),
        ),
      );
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> mount(
    WidgetTester tester, {
    required String type,
    bool plan = false,
    String purpose = 'PERFORMER_CONSENT',
    String? action,
    AppLifecycleState initialLifecycle = AppLifecycleState.resumed,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(initialLifecycle);
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      final disposing = dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await disposing;
    });
    sessions.replace(
      audienceSession(
        user: _user,
        role: type == _requested ? 'ROLE_MUSICIAN' : 'ROLE_VENUE',
      ),
    );
    api.dto = {
      'id': _notification,
      'recipientId': _user,
      'type': type,
      'title': 'Snapshot title',
      'message': '',
      'read': false,
      'payload': {
        'module': plan ? 'EVENT_PLAN' : 'EVENT_PERFORMER',
        'action':
            action ??
            (type == _requested
                ? 'APPROVAL_REQUESTED'
                : type == _approved
                ? 'APPROVED'
                : 'REJECTED'),
        if (plan) 'planId': _plan else 'eventId': _event,
        if (!plan) 'requestId': 'c0000000-0000-4000-8000-000000000003',
        'requestPurpose': purpose,
        'musicianProfileId': _musician,
        'performerType': 'MUSICIAN',
        'targetType': 'MUSICIAN',
        'targetId': _musician,
        'venueId': _venue,
      },
    };
    notifications.items = [
      AppNotificationModel.fromJson(api.dto),
      AppNotificationModel.fromJson({
        ...api.dto,
        'id': _other,
        'title': 'Unrelated unread',
      }),
    ];
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<NotificationTargetRepository>(
      NotificationTargetRepository(api, sessions),
    );
    serviceLocator.registerSingleton<NotificationCubit>(cubit);
    serviceLocator.registerSingleton<VenueEventRepository>(events);
    serviceLocator.registerSingleton<EngagementRepository>(_Engagement());
    serviceLocator.registerSingleton<EventPlanRepository>(plans);
    serviceLocator.registerSingleton<MusicianProfileRepository>(profiles);
    serviceLocator.registerSingleton<VenueProfileRepository>(venues);
    serviceLocator.registerSingleton<EventPerformerRequestRepository>(requests);
    await cubit.ensureStarted();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [notificationTargetRouteObserver],
        home: NotificationDirectTestHost(
          opener: VenueNotificationOpenScreen(
            target: PushTarget(
              notificationId: _notification,
              recipientId: _user,
              type: type,
            ),
          ),
        ),
      ),
    );
  }

  void expectOneRead(WidgetTester tester, {int attempts = 1}) {
    expect(api.acks, List.filled(attempts, _notification));
    expect(
      api.contexts.every(
        (context) => context?.expectedToken == sessions.session.token,
      ),
      isTrue,
    );
    expect(
      notifications.items.singleWhere((row) => row.id == _notification).read,
      isTrue,
    );
    expect(
      notifications.items.singleWhere((row) => row.id == _other).read,
      isFalse,
    );
    expect(
      cubit.state.items.singleWhere((row) => row.id == _notification).read,
      isTrue,
    );
    expect(
      cubit.state.items.singleWhere((row) => row.id == _other).read,
      isFalse,
    );
    expect(cubit.state.unreadCount, 1);
    expect(comparisons, 1);
    expect(find.byType(NotificationScreen), findsNothing);
    expect(notifications.broadMutations, 0);
    expect(tester.takeException(), isNull);
  }

  Future<void> hide(WidgetTester tester, String reason) async {
    switch (reason) {
      case 'background':
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      case 'dialog':
        unawaited(
          showDialog<void>(
            context: navigator.currentContext!,
            builder: (_) => const AlertDialog(content: Text('Other dialog')),
          ),
        );
      case 'removed':
        unawaited(
          navigator.currentState!.pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Other destination')),
            ),
          ),
        );
      case 'token':
        sessions.replace(
          audienceSession(user: _user, role: 'ROLE_VENUE', token: 'new-token'),
        );
      case 'logout':
        sessions.replace(const AuthSession.guest());
      case 'account':
        sessions.replace(audienceSession(user: _other, role: 'ROLE_VENUE'));
    }
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, String reason) async {
    if (reason == 'background') {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    } else {
      navigator.currentState!.pop();
    }
    await tester.pumpAndSettle();
  }

  void expectNoRead(WidgetTester tester) {
    expect(api.acks, isEmpty);
    expect(notifications.items.every((row) => !row.read), isTrue);
    expect(cubit.state.items.every((row) => !row.read), isTrue);
    expect(comparisons, 0);
    expect(find.byType(NotificationScreen), findsNothing);
    expect(notifications.broadMutations, 0);
  }

  Future<void>? _disposing;
  Future<void> dispose() => _disposing ??= _dispose();
  Future<void> _dispose() async {
    await cubit.close();
    await realtime.dispose();
    sessions.dispose();
  }
}

class _Api extends Fake implements ApiClient {
  _Api(this.repository);
  final _Notifications repository;
  Map<String, dynamic> dto = {};
  bool offline = false, failAck = false;
  Completer<void>? ackPending;
  Completer<void>? getPending;
  int gets = 0;
  final acks = <String>[];
  final contexts = <ApiRequestContext?>[];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    contexts.add(requestContext);
    if (method == ApiHttpMethod.get) {
      gets++;
      expect(path, '/api/v1/user/notifications/${dto['id']}');
      await getPending?.future;
      if (offline) throw StateError('offline');
      return decoder!(dto);
    }
    expect(method, ApiHttpMethod.post);
    final notificationId = path.split('/')[5];
    expect(path, '/api/v1/user/notifications/$notificationId/read');
    expect(repository.items.any((row) => row.id == notificationId), isTrue);
    acks.add(notificationId);
    await ackPending?.future;
    if (failAck) throw StateError('offline');
    repository.items = repository.items
        .map((row) => row.id == notificationId ? row.copyWith(read: true) : row)
        .toList();
    return null as T;
  }
}

class _Notifications extends Fake implements NotificationRepository {
  List<AppNotification> items = [];
  int broadMutations = 0;
  @override
  Future<Result<Page<AppNotification>>> listNotifications({
    int page = 0,
    int size = 20,
  }) async => Result.success(Page(items: List.of(items), hasNext: false));
  @override
  Future<Result<int>> getUnreadCount() async =>
      Result.success(items.where((row) => !row.read).length);
  @override
  Future<Result<int>> markAllAsRead() async {
    broadMutations++;
    return const Result.success(0);
  }

  @override
  Future<Result<int>> clearAllNotifications() async {
    broadMutations++;
    return const Result.success(0);
  }
}

class _Tokens extends Fake implements TokenStore {
  @override
  Future<String?> readToken() async => null;
}

class _Realtime extends NotificationRealtimeClient {
  @override
  bool get isConnected => true;
  @override
  Future<void> connect({required String userId, required String token}) async {}
  @override
  Future<void> disconnect() async {}
}

class _Events extends Fake implements VenueEventRepository {
  bool missing = false;
  Completer<Result<VenueEventDetail>>? pending;
  final readIds = <String>[];
  final detail = const VenueEventDetail(
    id: _event,
    shareUrl: null,
    posterImage: null,
    performerName: 'Current manual performer',
    musicianProfileId: null,
    title: 'Current event',
    description: 'Current authored description',
    performerType: 'MANUAL',
  );
  @override
  Future<Result<VenueEventDetail>> getDetail(String id) async {
    readIds.add(id);
    return pending?.future ??
        (missing ? const Result.failure(_missing) : Result.success(detail));
  }
}

class _Plans extends Fake implements EventPlanRepository {
  String consent = 'PENDING', target = _musician;
  bool missing = false;
  List<EventPlan>? performerListItems;
  Map<int, List<EventPlan>>? performerPages;
  final performerListPages = <int>[];
  Completer<void>? performerListPending;
  Completer<Result<EventPlan>>? pending;
  Completer<Result<EventPlan>>? destinationPending;
  final ownerReads = <String>[],
      performerReads = <String>[],
      occurrenceReads = <String>[],
      performerLists = <String>[];
  EventPlan get value => valueFor();
  EventPlan valueFor({String id = _plan, String title = 'Current plan'}) =>
      EventPlan(
        id: id,
        version: 7,
        definition: EventPlanDefinition(
          venueId: _venue,
          startDate: DateTime(2027, 1, 1),
          untilDate: DateTime(2027, 1, 2),
          weekdays: [5, 6],
          excludedDates: [],
          template: EventPlanTemplate(
            title: title,
            startTime: '20:00',
            endTime: '21:00',
            musicianProfileId: target,
          ),
        ),
        venueName: 'Current venue',
        performerName: 'Current performer',
        status: 'ACTIVE',
        consentStatus: consent,
        showOnProfile: false,
        serverNow: DateTime.utc(2026, 9, 24),
        decisionAllowed: consent == 'PENDING',
        withdrawAllowed: consent == 'ACCEPTED',
      );
  Future<Result<EventPlan>> read() async =>
      pending?.future ??
      (missing ? const Result.failure(_missing) : Result.success(value));
  @override
  Future<Result<EventPlan>> getOwner(String planId) {
    ownerReads.add(planId);
    if (ownerReads.length > 1 && destinationPending != null) {
      return destinationPending!.future;
    }
    return read();
  }

  @override
  Future<Result<EventPlan>> getPerformer(String planId) {
    performerReads.add(planId);
    return read();
  }

  @override
  Future<Result<EventPlanPage<EventPlan>>> listPerformer(
    EventPerformerTargetType type,
    String targetId, {
    int page = 0,
  }) async {
    performerLists.add(targetId);
    performerListPages.add(page);
    await performerListPending?.future;
    return Result.success(
      EventPlanPage(
        items: performerPages?[page] ?? performerListItems ?? [value],
        page: page,
        hasNext: performerPages?.containsKey(page + 1) == true,
      ),
    );
  }

  @override
  Future<Result<EventPlanPage<EventPlanOccurrence>>> occurrences(
    String planId, {
    int page = 0,
  }) async {
    occurrenceReads.add(planId);
    return const Result.success(
      EventPlanPage(items: [], page: 0, hasNext: false),
    );
  }
}

class _Profiles extends Fake implements MusicianProfileRepository {
  bool reject = false;
  @override
  Future<Result<MusicianProfile>> getMyProfile() async => reject
      ? const Result.failure(_missing)
      : const Result.success(
          MusicianProfile(
            id: _musician,
            userId: _user,
            username: 'Fixture musician',
            stageName: null,
            bio: null,
            profilePicture: null,
            instagramUrl: null,
            youtubeUrl: null,
            soundcloudUrl: null,
            spotifyEmbedUrl: null,
            spotifyArtistId: null,
            spotifyTrackIds: [],
            spotifyTracks: [],
            instruments: [],
            activeVenues: [],
            bands: [],
          ),
        );
}

class _Requests extends InvitationRequests {
  Completer<void>? pending;
  @override
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  }) async {
    final result = await super.listMine(
      status: status,
      page: page,
      size: size,
      targetType: targetType,
      targetId: targetId,
    );
    await pending?.future;
    return result;
  }
}

class _Venues extends Fake implements VenueProfileRepository {
  String owner = _user;
  final readIds = <String?>[];
  @override
  Future<Result<VenueOwnerProfile>> getMyVenueProfileDetail({
    String? venueId,
  }) async {
    readIds.add(venueId);
    return Result.success(
      VenueOwnerProfile(
        venueProfileId: _venue,
        venueId: _venue,
        ownerUserId: owner,
        venueName: 'Current venue',
        bio: null,
        profilePictureUrl: null,
        instagramUrl: null,
        youtubeUrl: null,
        websiteUrl: null,
        address: null,
        phone: null,
        website: null,
        description: null,
        musicStartTime: null,
        cityId: null,
        cityName: null,
        districtId: null,
        districtName: null,
        neighborhoodId: null,
        neighborhoodName: null,
        status: 'APPROVED',
        activeMusicians: [],
        activeBands: [],
        weeklyEvents: [],
      ),
    );
  }
}

class _Engagement extends Fake implements EngagementRepository {
  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(CommentPage(items: [], totalElements: 0));
}
