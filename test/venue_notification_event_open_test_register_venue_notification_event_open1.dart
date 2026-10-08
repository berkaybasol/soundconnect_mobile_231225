part of 'venue_notification_event_open_test.dart';

extension _RegisterVenueNotificationEventOpen1
    on _VenueNotificationEventOpenCases {
  void _registerVenueNotificationEventOpen1() {
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
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
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

    testWidgets(
      'exact plan below the viewport waits until scrolled into view',
      (tester) async {
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
      },
    );

    for (final change in [
      'none',
      'visible-scroll',
      'hide-return-same-frame',
      'hidden-response',
      'transport-failure',
    ]) {
      testWidgets(
        'performer plan ACK recovery distinguishes $change without repeating target reads',
        (tester) async {
          f.plans.performerListItems = [
            f.plans.value,
            for (var i = 0; i < 8; i++)
              f.plans.valueFor(id: 'unrelated-$i', title: 'Unrelated plan $i'),
          ];
          f.api.ackPending = Completer<void>();
          f.api.failAck = change == 'transport-failure';
          await f.mount(tester, type: _requested, plan: true);
          await tester.pumpAndSettle();
          expect(f.api.acks, [_notification]);
          final marker = find.byKey(const ValueKey(_plan));
          final owner = tester.element(marker);
          final position = Scrollable.of(owner).position;
          final initialOffset = position.pixels;
          final hiddenOffset =
              initialOffset +
              tester.getRect(marker).bottom -
              tester.getRect(find.byType(ListView)).top +
              8;
          final reads = List.of(f.plans.performerReads);
          final lists = List.of(f.plans.performerLists);
          final gets = f.api.gets;
          final route = ModalRoute.of(owner);

          if (change == 'visible-scroll') {
            position.jumpTo(initialOffset + 12);
            await tester.pumpAndSettle();
            final visible = tester
                .getRect(marker)
                .intersect(tester.getRect(find.byType(ListView)));
            expect(visible.height, greaterThanOrEqualTo(48));
          } else if (change == 'hide-return-same-frame' ||
              change == 'hidden-response') {
            position.jumpTo(hiddenOffset);
            if (change == 'hide-return-same-frame') {
              // Both offsets change before another frame or HTTP completion.
              position.jumpTo(initialOffset);
            }
            await tester.pumpAndSettle();
          }
          if (change == 'hidden-response') {
            // The real sliver may dispose a wholly hidden long card. Its old
            // owner must be fenced just like a still-mounted hidden marker.
            expect(find.text(_retry), findsNothing);
          } else {
            expect(identical(tester.element(marker), owner), isTrue);
          }
          expect(f.api.acks.length, 1);
          expect(f.cubit.state.unreadCount, 2);
          expect(f.comparisons, 0);
          f.api.ackPending!.complete();
          await tester.pumpAndSettle();
          // Remote persistence and the local projection are separate contracts.
          expect(
            f.notifications.items
                .singleWhere((row) => row.id == _notification)
                .read,
            change != 'transport-failure',
          );
          if (change == 'none') {
            f.expectOneRead(tester);
            expect(find.text(_retry), findsNothing);
          } else {
            expect(f.cubit.state.items.every((row) => !row.read), isTrue);
            expect(f.cubit.state.unreadCount, 2);
            expect(f.comparisons, 0);
            if (change == 'hidden-response') {
              expect(find.text(_retry), findsNothing);
              position.jumpTo(initialOffset);
              await tester.pumpAndSettle();
            }
            expect(find.text(_retry), findsOneWidget);
            expect(f.api.acks.length, 1); // Returning does not retry.
            f.api.failAck = false;
            f.api.ackPending = Completer<void>();
            final action = tester
                .widget<SnackBarAction>(find.byType(SnackBarAction))
                .onPressed;
            await tester.tap(find.text(_retry));
            action(); // A retained/double action cannot overlap the retry.
            await tester.pump();
            expect(f.api.acks, [_notification, _notification]);
            expect(f.cubit.state.unreadCount, 2);
            f.api.ackPending!.complete();
            await tester.pumpAndSettle();
            f.expectOneRead(tester, attempts: 2);
            expect(find.text(_retry), findsNothing);
          }
          expect(f.api.gets, gets);
          expect(f.plans.performerReads, reads);
          expect(f.plans.performerLists, lists);
          expect(f.plans.ownerReads, isEmpty);
          expect(f.plans.occurrenceReads, isEmpty);
          expect(f.requests.reads, 0);
          expect(
            identical(ModalRoute.of(tester.element(marker)), route),
            isTrue,
          );
          expect(find.byType(EventPlanPerformerScreen), findsOneWidget);
          await f.cubit.refresh();
          await f.cubit.loadMore();
          expect(
            f.cubit.state.items.singleWhere((row) => row.id == _other).read,
            isFalse,
          );
          expect(f.cubit.state.unreadCount, 1);
          expect(f.api.acks.length, change == 'none' ? 1 : 2);
        },
      );
    }

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
          final payload = Map<String, dynamic>.from(
            f.api.dto['payload'] as Map,
          );
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

    testWidgets(
      'invitation reentry resolves a plan destination independently',
      (tester) async {
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
      },
    );

    for (final hiding in [
      'dialog',
      'background',
      'removed',
      'token',
      'logout',
    ]) {
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
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
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
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
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
  }
}
