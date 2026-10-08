part of 'table_group_detail_lifecycle_test.dart';

void _registerTableGroupDetailLifecycle2() {
  testWidgets('accepted list overview defers chat resources until Masaya git', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 17, 18);
    final tokenStore = _UserTokenStore('guest');
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 24)),
        meetingAt: now.add(const Duration(hours: 3)),
        description: 'Bu akşam birlikte müzik dinleyelim.',
        includeGuest: true,
      ),
    );
    final transport = _ImmediateTransportHarness();
    await serviceLocator.reset();
    serviceLocator.registerSingleton<DmBadgeCubit>(
      DmBadgeCubit(
        _DetailDmRepository(),
        tokenStore,
        realtimeClient: _DetailNoopDmRealtimeClient(),
      ),
      dispose: (cubit) => cubit.close(),
    );
    addTearDown(serviceLocator.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(
            tableGroupId: 'g-1',
            openChat: false,
          ),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: tokenStore,
          realtimeClient: TableGroupChatRealtimeClient(
            transportFactory: transport.create,
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masaya git'), findsOneWidget);
    expect(repository.chatCalls, 0);
    expect(transport.created, 0);

    await tester.tap(find.byKey(const Key('table_group_detail_sticky_action')));
    await tester.pumpAndSettle();

    expect(repository.chatCalls, 1);
    expect(transport.created, 1);
    expect(
      find.byKey(const ValueKey<String>('table-group-game-launcher')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('table_group_detail_overview')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('full table detail stays readable but cannot be joined', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 17, 18);
    const description = 'Bu dolu masanın açıklaması yine okunabilmeli.';
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
        description: description,
        maxPersonCount: 1,
      ),
    );
    final realtimeClient = TableGroupChatRealtimeClient(
      transportFactory: (_) =>
          throw StateError('Outsider must not connect to table chat'),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _UserTokenStore('viewer'),
          realtimeClient: realtimeClient,
          now: () => now,
          canCreateOrJoin: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Katıl'), findsNothing);
    expect(
      find.text(
        'Bu masadaki tüm yerler dolmuş. Başka bir masaya göz atabilirsin.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('table_group_description_card')),
      findsOneWidget,
    );
    expect(repository.joinCalls, 0);
    expect(repository.chatCalls, 0);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('table_group_description_card')));
    await tester.pumpAndSettle();
    expect(find.text(description), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('expiry timer closes chat and disconnects its scoped client', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(seconds: 1)),
        description: 'Sohbet öncesi masa açıklaması',
      ),
    );
    final transport = _ImmediateTransportHarness();
    final realtimeClient = TableGroupChatRealtimeClient(
      transportFactory: transport.create,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _OwnerTokenStore(),
          realtimeClient: realtimeClient,
          now: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Mesaj yaz'), findsOneWidget);
    expect(
      find.byKey(const Key('table_group_description_card')),
      findsOneWidget,
    );
    expect(repository.chatCalls, 1);
    expect(transport.created, 1);

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('Bu masa sona erdi'), findsOneWidget);
    expect(find.text('Mesaj yaz'), findsNothing);
    expect(transport.latest?.deactivated, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'injected realtime client remains reusable after screen disposal',
    (tester) async {
      final now = DateTime.utc(2026, 8, 17, 18);
      final transport = _ImmediateTransportHarness();
      final realtimeClient = _TrackingTableGroupChatRealtimeClient(
        transportFactory: transport.create,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TableGroupDetailScreen(
            args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
            repository: _DetailRepository(
              group: _group(
                status: 'ACTIVE',
                expiresAt: now.add(const Duration(hours: 1)),
              ),
            ),
            gameRepository: const _NoActiveGameRepository(),
            tokenStore: const _OwnerTokenStore(),
            realtimeClient: realtimeClient,
            now: () => now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(transport.created, 1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(transport.latest?.deactivated, isTrue);
      expect(realtimeClient.disposeCalls, 0);
      expect(realtimeClient.disconnectCalls, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'failed exact chat retry reuses key and changed text rotates it',
    (tester) async {
      final now = DateTime.utc(2026, 8, 17, 18);
      final repository = _DetailRepository(
        group: _group(
          status: 'ACTIVE',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
        sendFailuresRemaining: 2,
      );
      final transport = _ImmediateTransportHarness();
      final realtimeClient = TableGroupChatRealtimeClient(
        transportFactory: transport.create,
      );
      final requestIds = <String>[
        '10000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000002',
        '10000000-0000-0000-0000-000000000003',
      ];
      var requestIdIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: TableGroupDetailScreen(
            args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
            repository: repository,
            gameRepository: const _NoActiveGameRepository(),
            tokenStore: const _OwnerTokenStore(),
            realtimeClient: realtimeClient,
            chatRequestIdFactory: () => requestIds[requestIdIndex++],
            now: () => now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final input = find.byType(TextField).last;
      await tester.enterText(input, '  response may be lost  ');
      await tester.tap(find.text('Gonder').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Gonder').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.sentChatContents, <String>[
        'response may be lost',
        'response may be lost',
      ]);
      expect(repository.sentClientMessageIds, <String?>[
        requestIds[0],
        requestIds[0],
      ]);

      await tester.enterText(input, 'changed content');
      await tester.tap(find.text('Gonder').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(input, 'changed content');
      await tester.tap(find.text('Gonder').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.sentClientMessageIds, <String?>[
        requestIds[0],
        requestIds[0],
        requestIds[1],
        requestIds[2],
      ]);
      expect(requestIdIndex, 3);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('reconnect waits for an in-flight history load then reconciles', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );
    final transport = _ImmediateTransportHarness();

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _OwnerTokenStore(),
          realtimeClient: TableGroupChatRealtimeClient(
            transportFactory: transport.create,
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(repository.chatCalls, 1);

    final blockedLoad = Completer<Result<pagination.Page<TableGroupMessage>>>();
    repository.nextChatResponse = blockedLoad;
    await tester.tap(find.byTooltip('Yenile'));
    await tester.pump();
    expect(repository.chatCalls, 2);

    transport.latest!.config.onSocketDone!.call();
    transport.latest!.config.onConnect();
    await tester.pump();

    blockedLoad.complete(
      const Result.success(
        pagination.Page<TableGroupMessage>(
          items: <TableGroupMessage>[],
          hasNext: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(repository.chatCalls, 3);
    expect(find.textContaining('Canli baglanti kesildi'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('incoming chat bubble stays within a narrow phone layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
      messages: <TableGroupMessage>[
        TableGroupMessage(
          messageId: 'long-message',
          tableGroupId: 'g-1',
          senderId: 'another-user',
          content: List<String>.filled(18, 'uzun mesaj').join(' '),
          messageType: 'TEXT',
          sentAt: now,
          deletedAt: null,
        ),
      ],
    );
    final transport = _ImmediateTransportHarness();

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _OwnerTokenStore(),
          realtimeClient: TableGroupChatRealtimeClient(
            transportFactory: transport.create,
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('uzun mesaj'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('accepted chat opens the three-mode game launcher', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );
    final transport = _ImmediateTransportHarness();

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _OwnerTokenStore(),
          realtimeClient: TableGroupChatRealtimeClient(
            transportFactory: transport.create,
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final launcher = find.byKey(
      const ValueKey<String>('table-group-game-launcher'),
    );
    expect(launcher, findsOneWidget);
    await tester.tap(launcher);
    await tester.pumpAndSettle();

    expect(find.text('Taş Kağıt Makas'), findsOneWidget);
    expect(find.text('Zar'), findsOneWidget);
    expect(find.text('Oylama'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'failed active-game lookup falls back to the newest history game',
    (tester) async {
      final now = DateTime.utc(2026, 8, 17, 18);
      final oldGame = _lobbyGameMessage(
        gameId: 'game-old',
        sentAt: now.subtract(const Duration(minutes: 2)),
      );
      final newestGame = _lobbyGameMessage(
        gameId: 'game-new',
        sentAt: now.subtract(const Duration(minutes: 1)),
      );
      final repository = _DetailRepository(
        group: _group(
          status: 'ACTIVE',
          expiresAt: now.add(const Duration(hours: 1)),
          includeGuest: true,
        ),
        messages: <TableGroupMessage>[oldGame, newestGame],
      );
      final transport = _ImmediateTransportHarness();

      await tester.pumpWidget(
        MaterialApp(
          home: TableGroupDetailScreen(
            args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
            repository: repository,
            gameRepository: const _FailingActiveGameRepository(),
            tokenStore: const _UserTokenStore('guest'),
            realtimeClient: TableGroupChatRealtimeClient(
              transportFactory: transport.create,
            ),
            now: () => now,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final newestCard = find.byKey(
        const ValueKey<String>('table-group-game-game-new'),
      );
      final newestJoin = find.descendant(
        of: newestCard,
        matching: find.byKey(const ValueKey<String>('table-group-game-join')),
      );
      expect(newestJoin, findsOneWidget);
      expect(tester.widget<FilledButton>(newestJoin).onPressed, isNotNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('table-group-game-game-old')),
          matching: find.text('Bu oyun artık aktif değil.'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('a realtime message survives a stale page-zero completion', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );
    final transport = _ImmediateTransportHarness();

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _OwnerTokenStore(),
          realtimeClient: TableGroupChatRealtimeClient(
            transportFactory: transport.create,
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final blockedLoad = Completer<Result<pagination.Page<TableGroupMessage>>>();
    repository.nextChatResponse = blockedLoad;
    await tester.tap(find.byTooltip('Yenile'));
    await tester.pump();

    transport.latest!.deliver(
      '/topic/table-group.g-1',
      jsonEncode(<String, dynamic>{
        'messageId': 'from-realtime',
        'tableGroupId': 'g-1',
        'senderId': 'another-user',
        'clientMessageId': 'client-from-realtime',
        'content': 'realtime korunmali',
        'messageType': 'TEXT',
        'sentAt': '2026-08-17T18:00:01Z',
      }),
    );
    await tester.pump();
    expect(find.text('realtime korunmali'), findsOneWidget);

    blockedLoad.complete(
      const Result.success(
        pagination.Page<TableGroupMessage>(
          items: <TableGroupMessage>[],
          hasNext: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('realtime korunmali'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('owner can confirm removal of an accepted participant', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
        includeGuest: true,
      ),
    );
    final transport = _ImmediateTransportHarness();

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _OwnerTokenStore(),
          realtimeClient: TableGroupChatRealtimeClient(
            transportFactory: transport.create,
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey<String>('kick-guest')));
    await tester.pumpAndSettle();
    expect(find.text('Katilimciyi masadan cikar'), findsOneWidget);
    expect(
      find.byKey(const Key('table_group_confirmation_dialog')),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Masadan Cikar'));
    await tester.pump();
    await tester.pump();

    expect(repository.kickCalls, 1);
    expect(repository.lastKickedParticipantId, 'guest');

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('owner request card renders a bounded nonblank join note', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
        includePending: true,
      ),
    );
    final transport = _ImmediateTransportHarness();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _OwnerTokenStore(),
          realtimeClient: TableGroupChatRealtimeClient(
            transportFactory: transport.create,
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('21:00 gibi oradayim'), findsOneWidget);
    final note = tester.widget<Text>(find.text('21:00 gibi oradayim'));
    expect(note.maxLines, 2);
    expect(note.overflow, TextOverflow.ellipsis);

    final approve = find.byKey(
      const ValueKey<String>('table_group_approve-pending-user'),
    );
    final reject = find.byKey(
      const ValueKey<String>('table_group_reject-pending-user'),
    );
    expect(tester.getSize(approve), const Size.square(48));
    expect(tester.getSize(reject), const Size.square(48));
    expect(
      tester.getSemantics(approve).label,
      contains('Pending User kullanıcısını onayla'),
    );

    await tester.tap(approve);
    await tester.pumpAndSettle();
    expect(repository.approveCalls, 0);
    expect(find.text('Katılım talebini onayla?'), findsOneWidget);
    expect(
      find.text("@Pending User'nin masaya katılım talebini onaylıyor musunuz?"),
      findsOneWidget,
    );
    expect(find.textContaining('oyun geçmişi'), findsNothing);
    final confirmationScheme = Theme.of(
      tester.element(find.text('Katılım talebini onayla?')),
    ).colorScheme;
    expect(confirmationScheme.brightness, Brightness.dark);
    expect(
      tester.widget<Text>(find.text('Katılım talebini onayla?')).style?.color,
      confirmationScheme.onSurface,
    );
    expect(
      tester
          .widget<Text>(
            find.text(
              "@Pending User'nin masaya katılım talebini onaylıyor musunuz?",
            ),
          )
          .style
          ?.color,
      confirmationScheme.onSurfaceVariant,
    );
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    expect(repository.approveCalls, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
