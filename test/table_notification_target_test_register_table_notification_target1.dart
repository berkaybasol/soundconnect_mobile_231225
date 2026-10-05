part of 'table_notification_target_test.dart';

extension _RegisterTableNotificationTarget1 on _TableNotificationTargetCases {
  void _registerTableNotificationTarget1() {
    setUp(() async {
      await serviceLocator.reset();
      sessions = AudienceTestSessions(
        audienceSession(user: recipient, role: 'ROLE_LISTENER'),
      );
      inbox = _Inbox();
      acks = [];
      response = targetJson();
      nav = GlobalKey<NavigatorState>();
      routes = _Routes();
      failGet = false;
      failAck = false;
      failChat = false;
      failDetail = false;
      pendingGet = null;
      pendingAck = null;
      pendingChat = null;
      reconciliations = 0;
      api = RecordingApiClient((request) async {
        if (request.path.endsWith('/read')) {
          acks.add(request.path.split('/').reversed.elementAt(1));
          if (pendingAck != null) await pendingAck!.future;
          if (failAck) throw ApiException(fail);
          inbox.items = inbox.items
              .map((i) => i.id == acks.last ? i.copyWith(read: true) : i)
              .toList();
          return null;
        }
        if (request.path.endsWith('/table-target')) {
          if (pendingGet != null) return await pendingGet!.future;
          if (failGet) throw ApiException(fail);
          return response;
        }
        if (request.path.endsWith('/chat/messages')) {
          if (pendingChat != null) await pendingChat!.future;
          if (failChat) throw ApiException(fail);
          return {'content': <Object>[], 'last': true};
        }
        if (request.path.contains('/approve/') ||
            request.path.contains('/reject/')) {
          return null;
        }
        throw StateError('Unexpected request ${request.path}');
      });
      targets = NotificationTargetRepository(api, sessions);
      cubit = NotificationCubit(
        inbox,
        _Tokens(),
        sessions: sessions,
        realtimeClient: _Realtime(),
        onDeliveryStateChanged: () async {
          reconciliations++;
        },
      );
      serviceLocator
        ..registerSingleton<AuthSessionManager>(sessions)
        ..registerSingleton<NotificationTargetRepository>(targets)
        ..registerSingleton<NotificationCubit>(cubit)
        ..registerSingleton<TokenStore>(_Tokens())
        ..registerSingleton<TableGroupRepository>(
          _TableFeed(() => response, unavailable: () => failDetail),
        )
        ..registerSingleton<TableGroupGameRepository>(_Games())
        ..registerSingleton<DmBadgeCubit>(_DmBadge(), dispose: (c) => c.close())
        ..registerFactory<TableGroupListCubit>(
          () => TableGroupListCubit(
            tableGroupRepository: _TableFeed(() => response),
            locationRepository: _Locations(),
          ),
        );
      await cubit.ensureStarted();
    });

    tearDown(() async {
      await serviceLocator.reset();
      await cubit.close();
      sessions.dispose();
    });

    for (final boundary in ['none', 'inactive', 'cover']) {
      testWidgets(
        'terminal pre-mount caller control $boundary releases same-ID opening',
        (t) async {
          response['tableStatus'] = 'CANCELLED';
          pendingGet = Completer<Object?>();
          await mount(t);
          var firstDone = false;
          final first = NotificationDirectOpen.start(
            inboxContext,
            identity: notificationId,
            builder: (_) =>
                TableNotificationOpenScreen(notification: item(notificationId)),
          );
          unawaited(first.then((_) => firstDone = true));
          await t.pump();
          expect(gets(), 1);
          expect(acks, isEmpty);
          // Flush the complete successful GET continuation, but do not build the
          // state scheduled by _closedTarget's setState yet.
          pendingGet!.complete(response);
          await t.idle();
          expect(find.byType(NotificationTerminalFeedback), findsNothing);
          expect(firstDone, isFalse);
          if (boundary == 'inactive') {
            // Unlike paused, inactive still permits real production frames.
            t.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
          } else if (boundary == 'cover') {
            unawaited(
              nav.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Pre-mount cover')),
                ),
              ),
            );
          }
          await settle(t);
          if (boundary != 'none') {
            expect(acks, isEmpty);
            expect(find.text('Bu masa kapatıldı.'), findsNothing);
            if (boundary == 'inactive') {
              t.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.resumed,
              );
            } else {
              nav.currentState!.pop();
            }
            await settle(t);
          }
          expect(find.text('Inbox'), findsOneWidget);
          expect(routes.stack.length, 2);
          // Recovery may present a terminal result or explicit retry. Either must
          // release the row; an invisible pending future cannot own it forever.
          final duplicate = NotificationDirectOpen.start(
            inboxContext,
            identity: notificationId,
            builder: (_) =>
                TableNotificationOpenScreen(notification: item(notificationId)),
          );
          final reusedPendingFlight = identical(first, duplicate) && !firstDone;
          expect(
            reusedPendingFlight,
            isFalse,
            reason:
                'Returning from $boundary must not retain an invisible '
                'same-ID flight that permanently disables the inbox row.',
          );
          await settle(t);
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    for (final boundary in ['none', 'inactive', 'cover']) {
      testWidgets(
        'terminal pre-mount $boundary presents once and releases real inbox row',
        (t) async {
          response['tableStatus'] = 'CANCELLED';
          pendingGet = Completer<Object?>();
          await mount(t, realInbox: true);
          final row = find
              .descendant(
                of: find.byKey(const ValueKey(notificationId)),
                matching: find.byType(InkWell),
              )
              .first;
          await t.tap(row);
          await t.pump();
          expect(gets(), 1);
          expect(t.widget<InkWell>(row).onTap, isNull);
          pendingGet!.complete(response);
          // Resolve the foreground GET without drawing the first presenter.
          await t.idle();
          expect(find.byType(NotificationTerminalFeedback), findsNothing);
          expect(acks, isEmpty);
          if (boundary == 'inactive') {
            t.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
          } else if (boundary == 'cover') {
            unawaited(
              nav.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Pre-mount cover')),
                ),
              ),
            );
          }
          await settle(t);
          if (boundary != 'none') {
            expect(acks, isEmpty);
            expect(find.text('Bu masa kapatıldı.'), findsNothing);
            unread();
            if (boundary == 'inactive') {
              expect(t.widget<InkWell>(row).onTap, isNull);
              t.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.resumed,
              );
            } else {
              nav.currentState!.pop();
            }
            await settle(t);
          }
          expect(find.byType(NotificationScreen), findsOneWidget);
          expect(find.text('Bu masa kapatıldı.'), findsOneWidget);
          expect(routes.stack.length, 2);
          expect(gets(), 1);
          expect(acks, [notificationId]);
          onlyTarget();
          expect(t.widget<InkWell>(row).onTap, isNotNull);
          pendingGet = Completer<Object?>();
          await t.tap(row);
          await t.pump();
          await t.tap(row);
          await t.pump();
          expect(gets(), 2, reason: 'Released row starts one new flight');
          expect(acks, [notificationId]);
          await t.pumpWidget(const SizedBox());
          pendingGet!.complete(response);
          await t.pump();
          expect(acks, [notificationId]);
        },
      );
    }

    for (final loss in ['logout', 'switch', 'relogin', 'pop', 'dispose']) {
      testWidgets(
        'terminal pre-mount inactive fences $loss and releases future',
        (t) async {
          response['tableStatus'] = 'CANCELLED';
          pendingGet = Completer<Object?>();
          await mount(t);
          var done = false;
          final first = NotificationDirectOpen.start(
            inboxContext,
            identity: notificationId,
            builder: (_) =>
                TableNotificationOpenScreen(notification: inbox.items.first),
          );
          unawaited(first.then((_) => done = true));
          await t.pump();
          pendingGet!.complete(response);
          await t.idle();
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          await settle(t);
          expect(done, isFalse);
          expect(acks, isEmpty);
          if (loss == 'pop') nav.currentState!.pop();
          if (loss == 'dispose') await t.pumpWidget(const SizedBox());
          if (['logout', 'switch', 'relogin'].contains(loss)) {
            await t.runAsync(() async {
              sessions.replace(
                loss == 'logout'
                    ? AuthSession.guest()
                    : audienceSession(
                        user: loss == 'switch' ? applicant : recipient,
                        token: 'replacement',
                      ),
              );
              await cubit.stop();
            });
          }
          await settle(t);
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await settle(t);
          expect(done, isTrue);
          expect(gets(), 1);
          expect(acks, isEmpty);
          expect(find.text('Bu masa kapatıldı.'), findsNothing);
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    for (final type in PushTarget.tableTypes) {
      for (final reason
          in type == 'TABLE_CANCELLED'
              ? ['OWNER_CANCELLED', 'OWNER_JOINED_ANOTHER_TABLE']
              : <String?>[null]) {
        testWidgets(
          'native TABLE $type $reason fresh terminal target and exact read',
          (t) async {
            response = targetJson(type: type, reason: reason);
            await mount(t);
            await open(
              t,
              native: true,
              selected: item(notificationId, type: type),
            );
            await settle(t);
            expect(gets(), 1);
            expect(acks, [notificationId]);
            onlyTarget();
            expect(find.text('Masa bildirimi'), findsNothing);
            if (response['tableStatus'] == 'ACTIVE') {
              nav.currentState!.pop();
              await settle(t);
            } else {
              expect(routes.stack.length, 2);
            }
            expect(find.text('Inbox'), findsOneWidget);
          },
        );
      }
    }

    testWidgets('native TABLE target failure then explicit fresh retry', (
      t,
    ) async {
      failGet = true;
      await mount(t);
      await open(t, native: true);
      await settle(t);
      unread();
      expect(gets(), 1);
      failGet = false;
      await t.tap(find.text('Tekrar dene'));
      await settle(t);
      expect(gets(), 2);
      expect(acks, [notificationId]);
      onlyTarget();
    });

    testWidgets('native TABLE ACK-only retry never repeats target GET', (
      t,
    ) async {
      failAck = true;
      await mount(t);
      await open(t, native: true);
      await settle(t);
      unread();
      expect(gets(), 1);
      expect(acks, [notificationId]);
      failAck = false;
      await t.tap(find.text('Tekrar dene'));
      await settle(t);
      expect(gets(), 1);
      expect(acks, [notificationId, notificationId]);
      onlyTarget();
    });

    testWidgets(
      'native TABLE hidden result needs explicit fresh retry and keeps sibling unread',
      (t) async {
        pendingGet = Completer<Object?>();
        await mount(t);
        await open(t, native: true);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        pendingGet!.complete(response);
        await t.pump();
        unread();
        pendingGet = null;
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(t);
        expect(gets(), 1);
        unread();
        await t.tap(find.text('Tekrar dene'));
        await settle(t);
        expect(gets(), 2);
        expect(acks, [notificationId]);
        onlyTarget();
      },
    );

    for (final boundary in ['background', 'cover']) {
      for (final failed in [false, true]) {
        testWidgets(
          'resume recovery $boundary ${failed ? "failure" : "success"}: visible retry completes future and resolves fresh once',
          (t) async {
            pendingGet = Completer<Object?>();
            await mount(t);
            var done = false;
            unawaited(
              NotificationDirectOpen.start(
                inboxContext,
                identity: notificationId,
                builder: (_) => TableNotificationOpenScreen(
                  notification: inbox.items.first,
                ),
              ).then((_) => done = true),
            );
            await t.pump();
            await t.pump(const Duration(milliseconds: 400));
            expect(gets(), 1);
            if (boundary == 'background') {
              t.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.paused,
              );
            } else {
              unawaited(
                nav.currentState!.push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Cover')),
                  ),
                ),
              );
              await settle(t);
            }
            if (failed) {
              pendingGet!.completeError(ApiException(fail));
            } else {
              pendingGet!.complete(response);
            }
            await settle(t);
            expect(acks, isEmpty);
            expect(find.byType(TableGroupDetailScreen), findsNothing);
            expect(find.text('Tekrar dene'), findsNothing);
            expect(done, isFalse);
            if (boundary == 'background') {
              t.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.resumed,
              );
            } else {
              nav.currentState!.pop();
            }
            await settle(t);
            final observed = [
              find.text('Bu masa şu anda açılamıyor.').evaluate().isNotEmpty,
              find.text('Tekrar dene').evaluate().isNotEmpty,
              done,
            ];
            debugPrint(
              'RESUME boundary=$boundary failed=$failed GET=${gets()} ACK=${acks.length} feedback/retry/done=$observed',
            );
            if (observed.any((v) => !v)) {
              await t.pumpWidget(const SizedBox());
              expect(observed, [true, true, true]);
              return;
            }
            expect(gets(), 1);
            unread();
            // Repeated lifecycle callbacks must not enqueue messages or auto-fetch.
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
            await settle(t);
            expect(find.byType(SnackBar), findsOneWidget);
            expect(gets(), 1);
            expect(acks, isEmpty);
            pendingGet = Completer<Object?>();
            await t.tap(find.text('Tekrar dene'));
            await t.pump();
            expect(gets(), 2);
            unread();
            // Only the explicit retry's changed fresh response may drive the target.
            response = {...response, 'description': 'Fresh retry table'};
            pendingGet!.complete(response);
            await settle(t);
            expect(gets(), 2);
            expect(find.byType(TableGroupDetailScreen), findsOneWidget);
            expect(
              t
                  .widget<TableGroupDetailScreen>(
                    find.byType(TableGroupDetailScreen),
                  )
                  .args
                  .notificationResult!
                  .description,
              'Fresh retry table',
            );
            expect(acks, [notificationId]);
            onlyTarget();
            expect(routes.stack.length, 3);
            nav.currentState!.pop();
            await settle(t);
            expect(find.text('Inbox'), findsOneWidget);
            expect(routes.stack.length, 2);
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }

    for (final action in ['row', 'retry then row', 'row then retry']) {
      testWidgets(
        'real inbox resume recovery releases row: $action is one fresh flight',
        (t) async {
          pendingGet = Completer<Object?>();
          await mount(t, realInbox: true);
          final row = find
              .descendant(
                of: find.byKey(const ValueKey(notificationId)),
                matching: find.byType(InkWell),
              )
              .first;
          await t.tap(row);
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          await t.tap(row);
          await t.pump();
          expect(gets(), 1);
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          pendingGet!.complete(response);
          await settle(t);
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await settle(t);
          expect(find.text('Tekrar dene'), findsOneWidget);
          unread();
          final retry = t
              .widget<SnackBarAction>(find.byType(SnackBarAction))
              .onPressed;
          pendingGet = Completer<Object?>();
          if (action == 'retry then row') {
            retry();
            await t.pump();
          }
          await t.tap(row);
          await t.pump();
          if (action == 'row then retry') retry();
          await t.pump(const Duration(milliseconds: 400));
          expect(
            gets(),
            2,
            reason:
                'The row is selectable; row plus retry shares one fresh resolver',
          );
          expect(acks, isEmpty);
          pendingGet!.complete(response);
          await settle(t);
          expect(gets(), 2);
          expect(find.byType(TableGroupDetailScreen), findsOneWidget);
          expect(routes.stack.length, 3);
          expect(acks, [notificationId]);
          onlyTarget();
          nav.currentState!.pop();
          await settle(t);
          expect(find.byType(NotificationScreen), findsOneWidget);
          expect(find.text('Tekrar dene'), findsNothing);
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    for (final loss in ['logout', 'switch', 'relogin', 'pop', 'dispose']) {
      for (final completedBeforeLoss in [false, true]) {
        testWidgets(
          'resume recovery discards $loss with completion before loss=$completedBeforeLoss',
          (t) async {
            pendingGet = Completer<Object?>();
            await mount(t);
            var done = false;
            unawaited(
              NotificationDirectOpen.start(
                inboxContext,
                identity: notificationId,
                builder: (_) => TableNotificationOpenScreen(
                  notification: inbox.items.first,
                ),
              ).then((_) => done = true),
            );
            await t.pump();
            await t.pump(const Duration(milliseconds: 400));
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
            if (completedBeforeLoss) {
              pendingGet!.completeError(ApiException(fail));
              await settle(t);
            }
            if (loss == 'pop') nav.currentState!.pop();
            if (loss == 'dispose') await t.pumpWidget(const SizedBox());
            if (['logout', 'switch', 'relogin'].contains(loss)) {
              await t.runAsync(() async {
                sessions.replace(
                  loss == 'logout'
                      ? AuthSession.guest()
                      : audienceSession(
                          user: loss == 'switch' ? applicant : recipient,
                          token: 'replacement',
                        ),
                );
                await cubit.stop();
              });
            }
            await settle(t);
            if (!completedBeforeLoss) {
              pendingGet!.complete(response);
              await settle(t);
            }
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
            await settle(t);
            expect(done, isTrue);
            expect(gets(), 1);
            expect(acks, isEmpty);
            expect(find.text('Tekrar dene'), findsNothing);
            expect(find.text('Bu masa şu anda açılamıyor.'), findsNothing);
            expect(find.byType(TableGroupDetailScreen), findsNothing);
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }

    for (final oldFailed in [false, true]) {
      testWidgets(
        'replacing a pending TABLE selection fences late ${oldFailed ? "failure" : "success"}',
        (t) async {
          final old = Completer<Object?>();
          pendingGet = old;
          await mount(t, realInbox: true);
          Finder row(String id) => find
              .descendant(
                of: find.byKey(ValueKey(id)),
                matching: find.byType(InkWell),
              )
              .first;
          await t.tap(row(notificationId));
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          pendingGet = Completer<Object?>();
          await t.tap(row(siblingId));
          await t.pump();
          await t.pump(const Duration(milliseconds: 400));
          expect(gets(), 2);
          if (oldFailed) {
            old.completeError(ApiException(fail));
          } else {
            old.complete(response);
          }
          await settle(t);
          expect(acks, isEmpty);
          expect(find.text('Tekrar dene'), findsNothing);
          expect(find.byType(TableGroupDetailScreen), findsNothing);
          response = targetJson(id: siblingId);
          pendingGet!.complete(response);
          await settle(t);
          expect(acks, [siblingId]);
          expect(cubit.state.items.first.read, isFalse);
          expect(cubit.state.items.last.read, isTrue);
          expect(cubit.state.unreadCount, 1);
          expect(routes.stack.length, 3);
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      'resolving keeps inbox visible and duplicate tap adds no route',
      (t) async {
        pendingGet = Completer<Object?>();
        await mount(t);
        await open(t);
        await open(t);
        expect(gets(), 1);
        expect(find.text('Inbox'), findsOneWidget);
        expect(find.text('Masa bildirimi'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(routes.stack.length, 2);
        unread();
        pendingGet!.complete(response);
        await settle(t);
        expect(routes.stack.length, 3);
        expect(find.byType(TableGroupDetailScreen), findsOneWidget);
        onlyTarget();
        await t.pumpWidget(const SizedBox());
      },
    );

    for (final entry in TableNotificationTarget.actions.entries) {
      for (final reason
          in entry.key == 'TABLE_CANCELLED'
              ? ['OWNER_CANCELLED', 'OWNER_JOINED_ANOTHER_TABLE']
              : [null]) {
        testWidgets(
          '${entry.key}/$reason uses active detail or closed origin feedback then exact read',
          (t) async {
            inbox.items = [
              item(notificationId, type: entry.key),
              item(siblingId),
            ];
            await cubit.refresh();
            response = targetJson(type: entry.key, reason: reason);
            await mount(t);
            await open(t);
            await settle(t);
            final closed = response['tableStatus'] != 'ACTIVE';
            expect(
              find.byType(TableGroupDetailScreen),
              closed ? findsNothing : findsOneWidget,
            );
            expect(find.byType(SnackBar), findsOneWidget);
            expect(find.text('Masa bildirimi'), findsNothing);
            expect(find.textContaining('Olay tarihi:'), findsNothing);
            expect(find.textContaining('güncel durumu:'), findsNothing);
            expect(
              api.requests.where((r) => r.path.endsWith('/chat/messages')),
              isEmpty,
            );
            expect(acks, [notificationId]);
            onlyTarget();
            expect(
              api.requests.every(
                (r) =>
                    r.requestContext?.expectedSessionKey == recipient &&
                    r.requestContext?.expectedToken == 'token',
              ),
              isTrue,
            );
            expect(routes.stack.length, closed ? 2 : 3);
            if (!closed) {
              nav.currentState!.pop();
              await settle(t);
            }
            expect(find.text('Inbox'), findsOneWidget);
            expect(routes.stack.length, 2);
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }

    for (final field in [
      'notificationId',
      'recipientId',
      'type',
      'tableGroupId',
      'subjectId',
      'event',
      'kind',
      'tableStatus',
      'participantStatus',
      'applicationId',
      'occurredAt',
      'sameApplication',
      'read',
    ]) {
      test('$field malformed or mismatched cannot resolve', () async {
        response[field] = 'invalid';
        final result = await targets.resolveTable(
          inbox.items.first,
          sessions.session,
        );
        expect(result.isSuccess, isFalse);
        expect(acks, isEmpty);
      });
    }
  }
}
