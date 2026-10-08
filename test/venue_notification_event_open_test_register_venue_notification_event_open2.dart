part of 'venue_notification_event_open_test.dart';

extension _RegisterVenueNotificationEventOpen2
    on _VenueNotificationEventOpenCases {
  void _registerVenueNotificationEventOpen2() {
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
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 350));
        expect(f.api.gets, 0);
        expect(f.requests.targetId, isNull);
        f.expectNoRead(tester);
      });
    }

    testWidgets(
      'deferred first GET failure needs explicit retry after resume',
      (tester) async {
        f.api.offline = true;
        await f.mount(
          tester,
          type: _requested,
          initialLifecycle: AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(f.api.gets, 1);
        expect(find.text('Tekrar dene'), findsOneWidget);
        f.api.offline = false;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(f.api.gets, 1);
        f.expectNoRead(tester);
        await tester.tap(find.text('Tekrar dene'));
        await tester.pumpAndSettle();
        expect(f.api.gets, 2);
        f.expectOneRead(tester);
      },
    );

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
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
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
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
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
}
