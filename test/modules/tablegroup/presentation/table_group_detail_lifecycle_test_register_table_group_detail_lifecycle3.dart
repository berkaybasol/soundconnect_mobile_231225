part of 'table_group_detail_lifecycle_test.dart';

void _registerTableGroupDetailLifecycle3() {
  testWidgets('leave confirmation uses correct Turkish copy', (tester) async {
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
        includeGuest: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _UserTokenStore('guest'),
          realtimeClient: TableGroupChatRealtimeClient(
            transportFactory: (_) =>
                throw StateError('Overview must not connect to table chat'),
          ),
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('table_group_detail_more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masadan ayrıl'));
    await tester.pumpAndSettle();

    expect(find.text('Masadan ayrıl'), findsOneWidget);
    expect(
      find.text('Masadan ayrıldığında bu sohbete erişimin sona erecek.'),
      findsOneWidget,
    );
    expect(find.text('Ayrıl'), findsOneWidget);
    expect(find.textContaining('ayrildiginda'), findsNothing);
    expect(find.textContaining('erisimin'), findsNothing);

    await tester.tap(find.byKey(const Key('table_group_confirmation_cancel')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('table_group_confirmation_dialog')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('approval dialog keeps actions accessible at 320dp and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
        includePending: true,
        pendingUsername: 'Çok Uzun Erişilebilirlik Testi Kullanıcı Görünen Adı',
      ),
    );
    final transport = _ImmediateTransportHarness();

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
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

    final approve = find.byKey(
      const ValueKey<String>('table_group_approve-pending-user'),
    );
    final approveButton = find.descendant(
      of: approve,
      matching: find.byType(IconButton),
    );
    tester.widget<IconButton>(approveButton).onPressed!();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 640);
    await tester.pumpAndSettle();

    final confirm = find.byKey(const Key('table_group_confirmation_confirm'));
    final cancel = find.byKey(const Key('table_group_confirmation_cancel'));
    expect(
      find.byKey(const Key('table_group_confirmation_scroll')),
      findsOneWidget,
    );
    expect(confirm, findsOneWidget);
    expect(cancel, findsOneWidget);
    expect(tester.getTopLeft(confirm).dy, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(confirm).dy, lessThanOrEqualTo(640));
    expect(tester.getSize(confirm).height, 48);
    expect(tester.getSize(cancel).height, greaterThanOrEqualTo(48));
    final confirmSemantics = tester.getSemantics(confirm);
    expect(confirmSemantics.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(confirmSemantics.hasFlag(SemanticsFlag.isFocusable), isTrue);
    expect(confirmSemantics.label, contains('Onayla'));
    expect(tester.takeException(), isNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(repository.approveCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    semantics.dispose();
  });

  testWidgets('pending owner controls stay visible after chat scrolls latest', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
        includePending: true,
        extraPendingCount: 3,
      ),
      messages: List<TableGroupMessage>.generate(
        60,
        (index) => TableGroupMessage(
          messageId: 'history-$index',
          tableGroupId: 'g-1',
          senderId: index.isEven ? 'owner' : 'another-user',
          content: 'gecmis mesaji $index',
          messageType: 'TEXT',
          sentAt: now.add(Duration(seconds: index)),
          deletedAt: null,
        ),
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
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('gecmis mesaji 59'), findsOneWidget);
    expect(find.text('21:00 gibi oradayim').hitTestable(), findsOneWidget);
    expect(
      find.byIcon(Icons.check_rounded).hitTestable(),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.byIcon(Icons.close_rounded).hitTestable(),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('next valid frame clears a recoverable invalid-payload banner', (
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

    transport.latest!.deliver('/topic/table-group.g-1', '[]');
    await tester.pump();
    expect(
      find.text('Canli sohbetten gecersiz bir mesaj alindi.'),
      findsOneWidget,
    );

    transport.latest!.deliver(
      '/topic/table-group.g-1',
      jsonEncode(<String, dynamic>{
        'messageId': 'valid-after-invalid',
        'tableGroupId': 'g-1',
        'senderId': 'another-user',
        'clientMessageId': 'client-valid-after-invalid',
        'content': 'gecerli mesaj',
        'messageType': 'TEXT',
        'sentAt': '2026-08-17T18:00:01Z',
      }),
    );
    await tester.pump();

    expect(find.text('gecerli mesaj'), findsOneWidget);
    expect(
      find.text('Canli sohbetten gecersiz bir mesaj alindi.'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('connected recovery action reconciles an invalid payload', (
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

    transport.latest!.deliver('/topic/table-group.g-1', '[]');
    await tester.pump();
    expect(
      find.text('Canli sohbetten gecersiz bir mesaj alindi.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Baglan'));
    await tester.pump();
    await tester.pump();

    expect(repository.chatCalls, 2);
    expect(
      find.text('Canli sohbetten gecersiz bir mesaj alindi.'),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('manual history success clears a failed reconnect banner', (
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

    final failedLoad = Completer<Result<pagination.Page<TableGroupMessage>>>();
    repository.nextChatResponse = failedLoad;
    transport.latest!.config.onSocketDone!.call();
    transport.latest!.config.onConnect();
    await tester.pump();
    failedLoad.complete(
      const Result.failure(
        AppError(code: 'history_failed', message: 'Gecmis yuklenemedi'),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Canli baglanti kesildi'), findsOneWidget);
    expect(find.text('Gecmis yuklenemedi'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    await tester.pump();

    expect(repository.chatCalls, 3);
    expect(find.textContaining('Canli baglanti kesildi'), findsNothing);
    expect(find.text('Gecmis yuklenemedi'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('expired game performs only one bounded reconcile retry', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );
    final gameRepository = _ExpiryGameRepository(
      _expiringGameMessage(
        now: now,
        deadline: now.add(const Duration(seconds: 1)),
      ),
    );
    final transport = _ImmediateTransportHarness();

    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: gameRepository,
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
    expect(gameRepository.activeCalls, 1);
    expect(find.text('00:01'), findsOneWidget);

    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(gameRepository.detailCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(gameRepository.detailCalls, 2);

    await tester.pump(const Duration(seconds: 5));
    expect(gameRepository.detailCalls, 2);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
