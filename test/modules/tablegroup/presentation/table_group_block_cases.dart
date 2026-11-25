part of 'table_group_detail_lifecycle_test.dart';

void _registerTableGroupBlockCases() {
  final now = DateTime.utc(2026, 11, 25, 19);
  final expiry = now.add(const Duration(hours: 1));
  test(
    'shared game with a hidden creator decodes without revealing the author',
    () {
      final raw = {
        'messageId': 'card',
        'tableGroupId': 'table',
        'senderId': null,
        'content': 'Hesap Kimde oyunu',
        'messageType': 'GAME',
        'sentAt': now.toIso8601String(),
        'game': {
          'schemaVersion': 1,
          'gameId': 'game',
          'tableGroupId': 'table',
          'revision': 1,
          'round': 1,
          'topic': 'WHO_PAYS',
          'mode': 'VOTE',
          'status': 'IN_PROGRESS',
          'phase': 'VOTE',
          'createdBy': null,
          'createdByUsername': null,
          'players': [],
          'revealedActions': [],
        },
      };
      final model = TableGroupMessageModel.fromWireJson(raw);
      expect(model.senderId, isNull);
      expect(model.game!.createdBy, isNull);
      expect(model.game!.supportsWhoPaysInteraction, isTrue);
      expect(
        () => TableGroupMessageModel.fromWireJson({
          ...raw,
          'messageType': 'TEXT',
          'clientMessageId': 'client',
          'game': null,
        }),
        throwsFormatException,
      );
    },
  );
  Widget screen(
    _DetailRepository repo,
    String viewer,
    _ImmediateTransportHarness transport, {
    bool openChat = true,
    AudienceTestSessions? sessions,
  }) => MaterialApp(
    home: TableGroupDetailScreen(
      args: TableGroupDetailArgs(tableGroupId: 'g-1', openChat: openChat),
      sessions: sessions,
      repository: repo,
      gameRepository: const _NoActiveGameRepository(),
      tokenStore: _UserTokenStore(viewer),
      realtimeClient: TableGroupChatRealtimeClient(
        transportFactory: transport.create,
      ),
      now: () => now,
      canCreateOrJoin: () => true,
    ),
  );

  testWidgets(
    'joining is optional and acknowledges only blocked members shown in the dialog',
    (tester) async {
      serviceLocator.registerSingleton<DmBadgeCubit>(
        DmBadgeCubit(
          _DetailDmRepository(),
          const _UserTokenStore('visitor'),
          realtimeClient: _DetailNoopDmRealtimeClient(),
        ),
        dispose: (cubit) => cubit.close(),
      );
      addTearDown(serviceLocator.reset);
      final repo = _DetailRepository(
        group: _group(status: 'ACTIVE', expiresAt: expiry, ownerBlocked: true),
      );
      await tester.pumpWidget(
        screen(repo, 'visitor', _ImmediateTransportHarness(), openChat: false),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Katıl'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Engellediğiniz @Owner da bu masada'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Vazgeç'));
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(repo.joinCalls, 0);
      await tester.tap(find.text('Katıl'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Katılma isteği gönder'));
      await tester.tap(find.text('Katılma isteği gönder'));
      await tester.pumpAndSettle();
      expect(repo.acknowledgedBlocks, ['owner']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a failed optional block preserves the report and retries only the message author',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession(user: 'guest'));
      final reports = RecordingApiClient(
        (_) => {'id': 'receipt', 'reportedAt': now.toIso8601String()},
      );
      var attempts = 0;
      final messages = [
        TableGroupMessage(
          messageId: 'reported',
          tableGroupId: 'g-1',
          senderId: 'owner',
          clientMessageId: 'reported-client',
          content: 'Bildireceğim mesaj',
          messageType: 'TEXT',
          sentAt: now,
          deletedAt: null,
        ),
      ];
      final blocks = RecordingApiClient((_) {
        if (++attempts == 1) throw StateError('temporary failure');
        messages.clear();
        return {'blockedByMe': true, 'interactionBlocked': true};
      });
      serviceLocator.registerSingleton<TableGroupReportRepository>(
        TableGroupReportRepository(reports, sessions),
      );
      serviceLocator.registerSingleton<UserBlockRepository>(
        UserBlockRepository(blocks, sessions),
      );
      addTearDown(serviceLocator.reset);
      final repo = _DetailRepository(
        group: _group(status: 'ACTIVE', expiresAt: expiry, includeGuest: true),
        messages: messages,
      );
      await tester.pumpWidget(
        screen(repo, 'guest', _ImmediateTransportHarness(), sessions: sessions),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Bildireceğim mesaj'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Para talebi'));
      await tester.ensureVisible(find.text('Bildirimi gönder'));
      await tester.tap(find.text('Bildirimi gönder'));
      await tester.pumpAndSettle();
      expect(blocks.requests, isEmpty);
      await tester.tap(find.text('Engelle'));
      await tester.pumpAndSettle();
      expect(find.text('Bildirimin alındı'), findsOneWidget);
      await tester.tap(find.text('Engelle'));
      await tester.pumpAndSettle();
      expect(reports.requests, hasLength(1));
      expect(
        blocks.requests.map((r) => r.path),
        List.filled(2, '/api/v1/users/me/blocks/owner'),
      );
      expect(find.text('Bildireceğim mesaj'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'first broker receipt recovers an unseen arrival and discards pre-receipt history',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      late void Function() receipt;
      final transport = _ImmediateTransportHarness(
        receiptHandler: (ready) => receipt = ready,
      );
      final before = TableGroupMessage(
        messageId: 'old',
        tableGroupId: 'g-1',
        senderId: 'guest',
        clientMessageId: 'old-client',
        content: 'Eski görünür mesaj',
        messageType: 'TEXT',
        sentAt: now,
        deletedAt: null,
      );
      final messages = [before];
      final repo = _DetailRepository(
        group: _group(status: 'ACTIVE', expiresAt: expiry),
        messages: messages,
      );
      await tester.pumpWidget(screen(repo, 'owner', transport));
      await tester.pumpAndSettle();
      expect(repo.detailCalls, 1);
      expect(find.text('Eski görünür mesaj'), findsOneWidget);
      final stale = Completer<Result<pagination.Page<TableGroupMessage>>>();
      repo.nextChatResponse = stale;
      await tester.tap(find.byTooltip('Yenile'));
      await tester.pump();
      // Acceptance and a visibility change happened before SUBSCRIBE was installed.
      // Neither event reaches the client. Only the eventual receipt is delivered.
      repo.group = _group(
        status: 'ACTIVE',
        expiresAt: expiry,
        includeGuest: true,
        guestBlocked: true,
        guestArrivedLater: true,
      );
      messages.clear();
      final callsBeforeReceipt = repo.detailCalls;
      receipt();
      await tester.pumpAndSettle();
      expect(repo.detailCalls, callsBeforeReceipt + 1);
      expect(
        find.text('Engellediğiniz @Guest masaya katıldı.'),
        findsOneWidget,
      );
      expect(find.text('Eski görünür mesaj'), findsNothing);
      stale.complete(
        Result.success(pagination.Page(items: [before], hasNext: false)),
      );
      await tester.tap(find.text('Masada kal'));
      await tester.pumpAndSettle();
      receipt();
      await tester.pumpAndSettle();
      expect(repo.detailCalls, callsBeforeReceipt + 1);
      expect(find.text('Engellediğiniz @Guest masaya katıldı.'), findsNothing);
      expect(find.text('Eski görünür mesaj'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'broker without receipts stays connected and checks durable membership without repeated history resets',
    (tester) async {
      final transport = _ImmediateTransportHarness(receiptHandler: (_) {});
      final repo = _DetailRepository(
        group: _group(status: 'ACTIVE', expiresAt: expiry),
      );
      await tester.pumpWidget(screen(repo, 'owner', transport));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      final historyReads = repo.chatCalls;
      final detailReads = repo.detailCalls;
      await tester.pump(const Duration(seconds: 30));
      await tester.pumpAndSettle();
      expect(repo.chatCalls, historyReads);
      expect(repo.detailCalls, detailReads + 1);
      expect(transport.created, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'an old session receipt cannot revalidate a reconnected subscription',
    (tester) async {
      final receipts = <void Function()>[];
      final transport = _ImmediateTransportHarness(
        receiptHandler: receipts.add,
      );
      final repo = _DetailRepository(
        group: _group(status: 'ACTIVE', expiresAt: expiry),
      );
      await tester.pumpWidget(screen(repo, 'owner', transport));
      await tester.pumpAndSettle();
      transport.latest!.config.onSocketDone!();
      transport.latest!.config.onConnect();
      expect(receipts, hasLength(2));
      final baseline = repo.detailCalls;
      receipts.first();
      await tester.pump();
      expect(repo.detailCalls, baseline);
      receipts.last();
      await tester.pumpAndSettle();
      expect(repo.detailCalls, baseline + 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final duringJoin in [false, true]) {
    testWidgets(
      duringJoin
          ? 'approval during a join POST survives its later stale pending response'
          : 'only the current applicant approval reloads an open pending table and shows a blocked arrival',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final sessions = AudienceTestSessions(audienceSession(user: 'guest'));
        final notices = _ImmediateTransportHarness();
        final personal = NotificationRealtimeClient(
          transportFactory: notices.create,
        );
        serviceLocator.registerSingleton<NotificationRealtimeClient>(personal);
        serviceLocator.registerSingleton<DmBadgeCubit>(
          DmBadgeCubit(
            _DetailDmRepository(),
            const _UserTokenStore('guest'),
            realtimeClient: _DetailNoopDmRealtimeClient(),
          ),
          dispose: (cubit) => cubit.close(),
        );
        addTearDown(() async {
          await personal.dispose();
          await serviceLocator.reset();
        });
        await personal.connect(userId: 'guest', token: 'fixture');
        final table = _ImmediateTransportHarness();
        final repo = _DetailRepository(
          group: _group(
            status: 'ACTIVE',
            expiresAt: expiry,
            includeGuest: !duringJoin,
            guestPending: true,
          ),
        );
        await tester.pumpWidget(
          screen(repo, 'guest', table, sessions: sessions, openChat: false),
        );
        await tester.pumpAndSettle();
        if (duringJoin) {
          repo.joinResponse = Completer<Result<void>>();
          await tester.tap(find.text('Katıl'));
          await tester.pumpAndSettle();
          final send = find.byKey(const Key('table_group_join_confirm'));
          await tester.ensureVisible(send);
          await tester.tap(send);
          await tester.pump();
          expect(repo.joinCalls, 1);
        } else {
          expect(find.text('Katılma isteği beklemede'), findsOneWidget);
        }
        final baseline = repo.detailCalls;
        void approve(
          String recipient,
          String tableId,
          String app,
          String owner,
        ) {
          notices.latest!.deliver(
            '/topic/notifications.guest',
            jsonEncode({
              'id': 'approval',
              'type': 'TABLE_JOIN_REQUEST_APPROVED',
              'recipientId': recipient,
              'payload': {
                'module': 'TABLE',
                'action': 'JOIN_REQUEST_APPROVED',
                'tableGroupId': tableId,
                'ownerId': owner,
                'applicationId': app,
              },
            }),
          );
        }

        approve('someone', 'g-1', 'guest-membership', 'owner');
        approve('guest', 'other', 'guest-membership', 'owner');
        approve('guest', 'g-1', 'guest-membership', 'wrong');
        await tester.pump();
        approve('guest', 'g-1', 'old-application', 'owner');
        await tester.pump();
        expect(repo.detailCalls, baseline);
        repo.group = _group(
          status: 'ACTIVE',
          expiresAt: expiry,
          includeGuest: true,
          additionalMembers: [
            const TableGroupParticipant(
              userId: 'eren',
              applicationId: 'eren-membership',
              username: 'Eren',
              status: TableGroupParticipantStatus.accepted,
              joinedAt: null,
              joinNote: null,
              profilePictureUrl: null,
              blockedByMe: true,
              blockedArrival: true,
            ),
          ],
        );
        approve('guest', 'g-1', 'guest-membership', 'wrong');
        approve('guest', 'g-1', 'guest-membership', 'owner');
        approve('guest', 'g-1', 'guest-membership', 'owner');
        if (duringJoin) {
          await tester.pump();
          expect(repo.detailCalls, baseline);
          final stalePending = Completer<Result<TableGroup>>();
          repo.nextDetailResponse = stalePending;
          repo.joinResponse!.complete(const Result.success(null));
          await tester.pump();
          expect(repo.detailCalls, baseline + 1);
          stalePending.complete(
            Result.success(
              _group(
                status: 'ACTIVE',
                expiresAt: expiry,
                includeGuest: true,
                guestPending: true,
              ),
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(
          find.text('Engellediğiniz @Eren masaya katıldı.'),
          findsOneWidget,
        );
        expect(table.created, 1);
        await tester.tap(find.text('Masada kal'));
        await tester.pumpAndSettle();
        final afterApproval = repo.detailCalls;
        approve('guest', 'g-1', 'guest-membership', 'owner');
        await tester.pumpAndSettle();
        expect(repo.detailCalls, afterApproval);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('late arrival recovered from detail, stay survives reopening', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repo = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: expiry,
        includeGuest: true,
        ownerBlocked: true,
        ownerArrivedLater: true,
      ),
    );
    await tester.pumpWidget(
      screen(repo, 'guest', _ImmediateTransportHarness()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Engellediğiniz @Owner masaya katıldı.'), findsOneWidget);
    await tester.tap(find.text('Masada kal'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      screen(repo, 'guest', _ImmediateTransportHarness()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Masadan ayrıl'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.group = _group(
      status: 'ACTIVE',
      expiresAt: expiry,
      includeGuest: true,
      guestMembership: 'rejoined-membership',
      ownerBlocked: true,
      ownerArrivedLater: true,
    );
    await tester.pumpWidget(
      screen(repo, 'guest', _ImmediateTransportHarness()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Engellediğiniz @Owner masaya katıldı.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'visibility change clears history and discards a pre-block response',
    (tester) async {
      final original = TableGroupMessage(
        messageId: 'old',
        tableGroupId: 'g-1',
        senderId: 'owner',
        clientMessageId: 'original',
        content: 'Engel öncesi',
        messageType: 'TEXT',
        sentAt: now,
        deletedAt: null,
      );
      final messages = [original];
      final repo = _DetailRepository(
        group: _group(status: 'ACTIVE', expiresAt: expiry, includeGuest: true),
        messages: messages,
      );
      final transport = _ImmediateTransportHarness();
      await tester.pumpWidget(screen(repo, 'guest', transport));
      await tester.pumpAndSettle();
      expect(find.text('Engel öncesi'), findsOneWidget);
      final stale = Completer<Result<pagination.Page<TableGroupMessage>>>();
      repo.nextChatResponse = stale;
      await tester.tap(find.byTooltip('Yenile'));
      await tester.pump();
      messages.clear();
      transport.latest!.deliver(
        '/topic/table-group.g-1.guest',
        jsonEncode({'tableGroupId': 'g-1', 'type': 'TABLE_VISIBILITY_CHANGED'}),
      );
      await tester.pumpAndSettle();
      expect(find.text('Engel öncesi'), findsNothing);
      stale.complete(
        Result.success(pagination.Page(items: [original], hasNext: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Engel öncesi'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
