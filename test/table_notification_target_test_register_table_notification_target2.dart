part of 'table_notification_target_test.dart';

extension _RegisterTableNotificationTarget2 on _TableNotificationTargetCases {
  void _registerTableNotificationTarget2() {
    testWidgets(
      'closed inaccessible result stays on origin with exact small message',
      (t) async {
        response['tableStatus'] = 'CANCELLED';
        await mount(t);
        await open(t);
        await settle(t);
        expect(find.byType(TableGroupListScreen), findsNothing);
        expect(find.byType(TableGroupDetailScreen), findsNothing);
        expect(find.text('Bu masa kapatıldı.'), findsOneWidget);
        onlyTarget();
        expect(routes.stack.length, 2);
        expect(find.text('Inbox'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      },
    );

    for (final native in [false, true]) {
      for (final status in ['CANCELLED', 'INACTIVE']) {
        testWidgets(
          'closed participant result $status native=$native has no extra Back',
          (t) async {
            response = targetJson(type: 'TABLE_PARTICIPANT_LEFT')
              ..['tableStatus'] = status;
            await mount(t);
            await open(
              t,
              native: native,
              selected: item(notificationId, type: 'TABLE_PARTICIPANT_LEFT'),
            );
            await settle(t);
            expect(find.text('Inbox'), findsOneWidget);
            expect(find.byType(TableGroupDetailScreen), findsNothing);
            expect(find.byType(TableGroupListScreen), findsNothing);
            expect(
              find.text(
                status == 'CANCELLED'
                    ? 'Bu masa kapatıldı.'
                    : 'Bu masanın süresi doldu.',
              ),
              findsOneWidget,
            );
            expect(routes.stack.length, 2);
            expect(gets(), 1);
            expect(acks, [notificationId]);
            onlyTarget();
            nav.currentState!.pop();
            await settle(t);
            expect(find.text('Home'), findsOneWidget);
            await t.pumpWidget(const SizedBox());
          },
        );
      }
    }

    testWidgets('closed origin ACK retry does not fetch the table again', (
      t,
    ) async {
      response['tableStatus'] = 'CANCELLED';
      failAck = true;
      await mount(t);
      await open(t);
      await settle(t);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Okundu bilgisi kaydedilemedi.'), findsOneWidget);
      expect(acks, [notificationId]);
      unread();
      failAck = false;
      await t.tap(find.text('Tekrar dene'));
      await settle(t);
      expect(gets(), 1);
      expect(acks, [notificationId, notificationId]);
      expect(routes.stack.length, 2);
      onlyTarget();
      await t.pumpWidget(const SizedBox());
    });

    for (final boundary in [
      'none',
      'cover',
      'background',
      'session',
      'replace',
    ]) {
      testWidgets(
        'closed origin queued message waits for paint and fences $boundary',
        (t) async {
          response['tableStatus'] = 'CANCELLED';
          await mount(t);
          final messenger = ScaffoldMessenger.of(inboxContext);
          messenger.showSnackBar(
            const SnackBar(content: Text('Önceki işlem mesajı'), persist: true),
          );
          await settle(t);
          await open(t);
          await settle(t);
          expect(find.text('Önceki işlem mesajı'), findsOneWidget);
          expect(find.text('Bu masa kapatıldı.'), findsNothing);
          expect(acks, isEmpty);
          if (boundary == 'cover') {
            unawaited(
              nav.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Cover')),
                ),
              ),
            );
          } else if (boundary == 'background') {
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
          } else if (boundary == 'session') {
            await t.runAsync(() async {
              sessions.replace(audienceSession(user: applicant));
              await Future<void>.delayed(Duration.zero);
            });
          } else if (boundary == 'replace') {
            unawaited(
              nav.currentState!.pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Replacement')),
                ),
              ),
            );
          }
          await settle(t);
          messenger.hideCurrentSnackBar();
          await settle(t);
          if (boundary == 'none') {
            expect(find.text('Bu masa kapatıldı.'), findsOneWidget);
            onlyTarget();
          } else {
            expect(acks, isEmpty);
          }
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets(
      'detail race falls back without read and fresh retry replaces failed route',
      (t) async {
        failDetail = true;
        await mount(t);
        await open(t);
        await settle(t);
        expect(find.byType(TableGroupListScreen), findsOneWidget);
        expect(find.text('Bu masa şu anda açılamıyor.'), findsOneWidget);
        expect(find.text('Başvurun kabul edilmedi.'), findsNothing);
        expect(acks, isEmpty);
        unread();
        expect(routes.stack.length, 3);
        failDetail = false;
        await t.tap(find.text('Tekrar dene'));
        await settle(t);
        expect(gets(), 2);
        expect(find.byType(TableGroupListScreen), findsNothing);
        expect(find.byType(TableGroupDetailScreen), findsOneWidget);
        expect(routes.stack.length, 3);
        onlyTarget();
        nav.currentState!.pop();
        await settle(t);
        expect(find.text('Inbox'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'target GET failure needs explicit retry, resume/rebuild do not retry',
      (t) async {
        failGet = true;
        await mount(t);
        await open(t);
        await settle(t);
        unread();
        expect(acks, isEmpty);
        expect(gets(), 1);
        expect(find.text('Inbox'), findsOneWidget);
        expect(find.text('Bu masa şu anda açılamıyor.'), findsOneWidget);
        expect(routes.stack.length, 2);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(t);
        expect(gets(), 1);
        failGet = false;
        await t.tap(find.text('Tekrar dene'));
        await settle(t);
        expect(gets(), 2);
        onlyTarget();
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets('first open waits for foreground', (t) async {
      await mount(t, paused: true);
      await open(t);
      expect(gets(), 0);
      unread();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(t);
      expect(gets(), 1);
      onlyTarget();
      await t.pumpWidget(const SizedBox());
    });

    testWidgets(
      'queued terminal message is not read until its real content paints',
      (t) async {
        final selected = inbox.items.first;
        final target = TableNotificationTarget.fromJson(response, selected);
        final ready = ValueNotifier(false);
        late BuildContext productContext;
        await mount(t);
        final route = MaterialPageRoute<void>(
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (_, visible, _) => NotificationTerminalFeedback(
              message: 'Başvurun kabul edilmedi.',
              contentIdentity: target,
              ready: visible,
              child: Scaffold(
                body: Builder(
                  builder: (context) {
                    productContext = context;
                    return const Text('Mevcut masa listesi');
                  },
                ),
              ),
            ),
          ),
        );
        NotificationTargetRead.table(
          notification: selected,
          cubit: cubit,
          sessions: sessions,
          repository: targets,
          content: target,
        ).attach(route);
        unawaited(nav.currentState!.push(route));
        await settle(t);
        ScaffoldMessenger.of(productContext).showSnackBar(
          const SnackBar(content: Text('Önceki işlem mesajı'), persist: true),
        );
        await settle(t);
        ready.value = true;
        await settle(t);
        expect(find.text('Önceki işlem mesajı'), findsOneWidget);
        expect(find.text('Başvurun kabul edilmedi.'), findsNothing);
        expect(acks, isEmpty);
        unread();
        ScaffoldMessenger.of(productContext).hideCurrentSnackBar();
        await settle(t);
        expect(find.text('Başvurun kabul edilmedi.'), findsOneWidget);
        onlyTarget();
        await t.pumpWidget(const SizedBox());
        ready.dispose();
      },
    );

    for (final boundary in ['cover', 'background', 'session']) {
      testWidgets('terminal before paint after $boundary cannot acknowledge', (
        t,
      ) async {
        final target = TableNotificationTarget.fromJson(
          response,
          inbox.items.first,
        );
        final ready = ValueNotifier(false);
        await mount(t);
        final route = MaterialPageRoute<void>(
          builder: (_) => ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (_, visible, _) => NotificationTerminalFeedback(
              message: 'Başvurun kabul edilmedi.',
              contentIdentity: target,
              ready: visible,
              child: const Scaffold(body: Text('Mevcut masa listesi')),
            ),
          ),
        );
        NotificationTargetRead.table(
          notification: target.notification,
          cubit: cubit,
          sessions: sessions,
          repository: targets,
          content: target,
        ).attach(route);
        unawaited(nav.currentState!.push(route));
        await settle(t);
        if (boundary == 'cover') {
          unawaited(
            nav.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Başka sayfa')),
              ),
            ),
          );
          await settle(t);
        } else if (boundary == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        } else {
          await t.runAsync(() async {
            sessions.replace(audienceSession(user: applicant));
            await cubit.stop();
          });
        }
        ready.value = true;
        await settle(t);
        expect(acks, isEmpty);
        expect(find.text('Başvurun kabul edilmedi.'), findsNothing);
        await t.pumpWidget(const SizedBox());
        ready.dispose();
      });
    }

    for (final boundary in [
      'cover',
      'pop',
      'switch',
      'logout',
      'relogin',
      'background',
    ]) {
      testWidgets('late target GET after $boundary never reads', (t) async {
        pendingGet = Completer<Object?>();
        await mount(t);
        await open(t);
        if (boundary == 'cover') {
          unawaited(
            nav.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Cover')),
              ),
            ),
          );
        }
        if (boundary == 'pop') nav.currentState!.pop();
        if (['switch', 'relogin', 'logout'].contains(boundary)) {
          await t.runAsync(() async {
            if (boundary == 'switch') {
              sessions.replace(audienceSession(user: applicant));
            }
            if (boundary == 'relogin') {
              sessions.replace(audienceSession(user: recipient, token: 'new'));
            }
            if (boundary == 'logout') sessions.replace(AuthSession.guest());
            await cubit.stop();
          });
        }
        if (boundary == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        }
        pendingGet!.complete(response);
        await settle(t);
        expect(acks, isEmpty);
        if (boundary == 'background') {
          t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          await settle(t);
          expect(gets(), 1);
          expect(acks, isEmpty);
        }
        await t.pumpWidget(const SizedBox());
      });
    }

    testWidgets(
      'ACK failure keeps result, explicit double retry single flight, no target GET or optimistic count',
      (t) async {
        failAck = true;
        await mount(t);
        await open(t);
        await settle(t);
        unread();
        expect(acks, [notificationId]);
        expect(find.byType(TableGroupDetailScreen), findsOneWidget);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(t);
        expect(acks.length, 1);
        failAck = false;
        pendingAck = Completer<Object?>();
        await t.tap(find.text('Tekrar dene'));
        await t.pump();
        await t.tap(find.text('Tekrar dene'));
        await t.pump();
        expect(acks.length, 2);
        expect(gets(), 1);
        unread();
        pendingAck!.complete(null);
        await settle(t);
        onlyTarget();
        expect(gets(), 1);
        await t.pumpWidget(const SizedBox());
      },
    );

    for (final closed in [false, true]) {
      testWidgets(
        'late ACK after cover closed=$closed does not project; explicit recovery on return',
        (t) async {
          if (closed) response['tableStatus'] = 'CANCELLED';
          pendingAck = Completer<Object?>();
          await mount(t);
          await open(t);
          await settle(t);
          expect(acks.length, 1);
          unawaited(
            nav.currentState!.push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Cover')),
              ),
            ),
          );
          await settle(t);
          pendingAck!.complete(null);
          await settle(t);
          unread();
          nav.currentState!.pop();
          await settle(t);
          expect(acks.length, 1);
          await t.tap(find.text('Tekrar dene'));
          await settle(t);
          onlyTarget();
          expect(gets(), 1);
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    testWidgets('second notification on same table has a new exact ticket', (
      t,
    ) async {
      await mount(t);
      await open(t);
      await settle(t);
      onlyTarget();
      nav.currentState!.pop();
      await settle(t);
      response = targetJson(id: siblingId);
      await open(t, selected: inbox.items.last);
      await settle(t);
      expect(acks, [notificationId, siblingId]);
      expect(cubit.state.unreadCount, 0);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets(
      'legacy or different cycle historical result does not show new pending actions',
      (t) async {
        response = targetJson(type: 'TABLE_JOIN_REQUEST_RECEIVED')
          ..['sameApplication'] = false
          ..['applicationId'] = null
          ..['participantStatus'] = 'PENDING';
        inbox.items = [
          item(notificationId, type: 'TABLE_JOIN_REQUEST_RECEIVED'),
          item(siblingId),
        ];
        await cubit.refresh();
        await mount(t);
        await open(t);
        await settle(t);
        expect(find.byType(TableGroupDetailScreen), findsOneWidget);
        expect(
          find.text('Bu bildirim önceki masa başvurusuna ait.'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('table-exact-application-$cycleId')),
          findsNothing,
        );
        expect(
          api.requests.where((r) => r.path.endsWith('/chat/messages')),
          isEmpty,
        );
        onlyTarget();
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'approved chat error stays unread and performs no chat read; explicit recovery',
      (t) async {
        failChat = true;
        await detail(t, pending: false);
        await settle(t);
        expect(acks, isEmpty);
        unread();
        expect(
          api.requests.where((r) => r.query?['markRead'] == true),
          isEmpty,
        );
        failChat = false;
        await t.tap(find.text('Tekrar dene'));
        await settle(t);
        expect(acks, [notificationId]);
        onlyTarget();
        expect(
          api.requests.where((r) => r.query?['markRead'] == true).length,
          1,
        );
        await t.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'clipped exact application stays unread until scrolled fully into its panel',
      (t) async {
        final selected = item(
          notificationId,
          type: 'TABLE_JOIN_REQUEST_RECEIVED',
        );
        final target = TableNotificationTarget.fromJson(
          targetJson(type: selected.type, kind: 'PENDING_APPLICATION'),
          selected,
        );
        final scroll = ScrollController();
        await mount(t);
        final route = MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 180,
                child: SingleChildScrollView(
                  controller: scroll,
                  child: Column(
                    children: [
                      const SizedBox(
                        height: 200,
                        child: Text('Other applicant only'),
                      ),
                      NotificationTargetReady(
                        requireVisibleBounds: true,
                        contentIdentity: target,
                        child: const SizedBox(
                          height: 100,
                          child: Text('Exact applicant'),
                        ),
                      ),
                      const SizedBox(height: 200),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        NotificationTargetRead.table(
          notification: target.notification,
          cubit: cubit,
          sessions: sessions,
          repository: targets,
          content: target,
        ).attach(route);
        unawaited(nav.currentState!.push(route));
        await settle(t);
        expect(acks, isEmpty);
        unread();
        scroll.jumpTo(60);
        await settle(t);
        expect(acks, isEmpty);
        unread(); // only part of exact row is visible
        scroll.jumpTo(200);
        await settle(t);
        expect(acks, [notificationId]);
        onlyTarget();
        await t.pumpWidget(const SizedBox());
        scroll.dispose();
      },
    );

    testWidgets(
      'owner exact request is visible before read; another newer row is insufficient',
      (t) async {
        pendingChat = Completer<Object?>();
        await detail(t, pending: true);
        expect(acks, isEmpty);
        unread();
        pendingChat!.complete(null);
        await settle(t);
        expect(find.text('Exact applicant'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('table-exact-application-$cycleId')),
          findsOneWidget,
        );
        expect(acks, [notificationId]);
        onlyTarget();
        await t.pumpWidget(const SizedBox());
      },
    );

    for (final pending in [true, false]) {
      testWidgets(
        'same user different cycle cannot open ${pending ? 'request' : 'chat'} or read',
        (t) async {
          await detail(t, pending: pending, wrongCycle: true);
          await settle(t);
          expect(acks, isEmpty);
          unread();
          expect(
            api.requests.where((r) => r.path.endsWith('/chat/messages')),
            isEmpty,
          );
          await t.pumpWidget(const SizedBox());
        },
      );
    }

    test('decision carries captured exact cycle and captured token', () async {
      final selected = item(
        notificationId,
        type: 'TABLE_JOIN_REQUEST_RECEIVED',
      );
      final target = TableNotificationTarget.fromJson(
        targetJson(type: selected.type, kind: 'PENDING_APPLICATION'),
        selected,
      );
      expect(
        (await targets.decideTableApplication(
          target,
          sessions.session,
          approve: true,
        )).isSuccess,
        isTrue,
      );
      expect(api.lastRequest.query, {'applicationId': cycleId});
      expect(api.lastRequest.requestContext?.expectedToken, 'token');
      expect(acks, isEmpty);
    });
  }
}
