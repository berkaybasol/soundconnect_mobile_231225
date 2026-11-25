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
