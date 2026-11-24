part of 'table_group_detail_lifecycle_test.dart';

void _registerReportEntryCases() {
  testWidgets(
    'personal moderation notice closes the matching chat even with an older page in flight',
    (tester) async {
      final now = DateTime.utc(2026, 11, 24, 14);
      final sessions = AudienceTestSessions(audienceSession(user: 'guest'));
      final personalTransport = _ImmediateTransportHarness();
      final personal = NotificationRealtimeClient(
        transportFactory: personalTransport.create,
      );
      serviceLocator.registerSingleton<NotificationRealtimeClient>(personal);
      addTearDown(() async {
        await personal.dispose();
        await serviceLocator.reset();
      });
      await personal.connect(userId: 'guest', token: 'fixture');
      final messages = [
        TableGroupMessageModel.fromWireJson({
          'messageId': 'older-id',
          'tableGroupId': 'g-1',
          'senderId': 'owner',
          'clientMessageId': 'older-client',
          'sentAt': now.toIso8601String(),
          'messageType': 'TEXT',
          'content': 'Eski masa mesajı.',
        }),
      ];
      final repo = _DetailRepository(
        group: _group(
          status: 'ACTIVE',
          expiresAt: now.add(const Duration(hours: 1)),
          includeGuest: true,
          description: 'Asıl masa açıklaması',
        ),
        messages: messages,
      );
      final chat = TableGroupChatRealtimeClient(
        transportFactory: _ImmediateTransportHarness().create,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TableGroupDetailScreen(
            args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
            sessions: sessions,
            now: () => now,
            repository: repo,
            gameRepository: const _NoActiveGameRepository(),
            tokenStore: const _UserTokenStore('guest'),
            realtimeClient: chat,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final channel = personalTransport.latest!.subscriptions.keys.singleWhere(
        (s) => s.endsWith('notifications.guest'),
      );
      void cancel(
        String table, {
        String reason = 'ADMIN_REMOVED',
        String recipient = 'guest',
      }) {
        personalTransport.latest!.deliver(
          channel,
          jsonEncode({
            'id': 'notice',
            'type': 'TABLE_CANCELLED',
            'recipientId': recipient,
            'payload': {
              'module': 'TABLE',
              'action': 'CANCELLED',
              'reason': reason,
              'tableGroupId': table,
            },
          }),
        );
      }

      cancel('other');
      cancel('g-1', recipient: 'other-user');
      await tester.pumpAndSettle();
      expect(find.text('Eski masa mesajı.'), findsOneWidget);
      final delayed = Completer<Result<pagination.Page<TableGroupMessage>>>();
      repo.nextChatResponse = delayed;
      await tester.tap(find.byTooltip('Yenile'));
      await tester.pump();
      // A profile update can replace the session object while retaining the
      // signed-in user and credentials.
      sessions.current = audienceSession(user: 'guest');
      cancel('g-1');
      await tester.pump();
      await tester.pump();
      expect(find.text('Bu masa yayından kaldırıldı.'), findsOneWidget);
      expect(find.text('Asıl masa açıklaması'), findsNothing);
      expect(find.text('Eski masa mesajı.'), findsNothing);
      expect(chat.isConnected, isFalse);
      delayed.complete(
        Result.success(pagination.Page(items: messages, hasNext: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Eski masa mesajı.'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      // A stale active detail cannot reopen a terminal table.
      await tester.tap(find.byTooltip('Yenile'));
      await tester.pumpAndSettle();
      expect(find.text('Bu masa yayından kaldırıldı.'), findsOneWidget);
      expect(chat.isConnected, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a visitor can report the public listing but cannot report a member incident',
    (tester) async {
      final now = DateTime.utc(2026, 11, 24, 14);
      final sessions = AudienceTestSessions(audienceSession(user: 'visitor'));
      serviceLocator.registerSingleton<DmBadgeCubit>(
        DmBadgeCubit(
          _DetailDmRepository(),
          const _UserTokenStore('visitor'),
          realtimeClient: _DetailNoopDmRealtimeClient(),
        ),
        dispose: (cubit) => cubit.close(),
      );
      final api = RecordingApiClient(
        (_) => {'id': 'receipt', 'reportedAt': now.toIso8601String()},
      );
      serviceLocator.registerSingleton<TableGroupReportRepository>(
        TableGroupReportRepository(api, sessions),
      );
      addTearDown(serviceLocator.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: TableGroupDetailScreen(
            args: const TableGroupDetailArgs(
              tableGroupId: 'g-1',
              openChat: false,
            ),
            sessions: sessions,
            now: () => now,
            repository: _DetailRepository(
              group: _group(
                status: 'ACTIVE',
                expiresAt: now.add(const Duration(hours: 1)),
                description: 'Akustik buluşma',
              ),
            ),
            gameRepository: const _NoActiveGameRepository(),
            tokenStore: const _UserTokenStore('visitor'),
            realtimeClient: TableGroupChatRealtimeClient(
              transportFactory: _ImmediateTransportHarness().create,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('table_group_detail_more')));
      await tester.pumpAndSettle();
      expect(find.text('Bir olay bildir'), findsNothing);
      await tester.tap(find.text('Masayı bildir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yanıltıcı bilgi'));
      await tester.tap(find.text('Bildirimi gönder'));
      await tester.pumpAndSettle();
      expect(find.text('Bildirimin alındı'), findsOneWidget);
      expect(api.lastRequest.path, '/api/v1/table-groups/g-1/reports');
      final body = api.lastRequest.body! as Map;
      expect(body['kind'], 'LISTING');
      expect(body['reason'], 'MISLEADING');
      expect(body.containsKey('messageId'), false);
      expect(body.containsKey('description'), false);
      expect(api.lastRequest.requestContext?.expectedSessionKey, 'visitor');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'report targets one peer text, retries the exact request and a later moderation event hides its content',
    (tester) async {
      final now = DateTime.utc(2026, 11, 24, 14);
      final sessions = AudienceTestSessions(audienceSession(user: 'guest'));
      var tries = 0;
      final api = RecordingApiClient((_) {
        if (++tries == 1) throw StateError('reply lost');
        return {'id': 'receipt', 'reportedAt': now.toIso8601String()};
      });
      serviceLocator.registerSingleton<TableGroupReportRepository>(
        TableGroupReportRepository(api, sessions),
      );
      addTearDown(serviceLocator.reset);
      final original = {
        'messageId': 'server-msg',
        'tableGroupId': 'g-1',
        'senderId': 'owner',
        'clientMessageId': 'client-msg',
        'sentAt': now.toIso8601String(),
        'messageType': 'TEXT',
        'content': 'Yer için ödeme istendi.',
      };
      final transport = _ImmediateTransportHarness();
      final group = _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
        includeGuest: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TableGroupDetailScreen(
            args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
            sessions: sessions,
            now: () => now,
            repository: _DetailRepository(
              group: group,
              messages: [
                TableGroupMessageModel.fromWireJson({
                  ...original,
                  'messageId': 'own-text',
                  'clientMessageId': 'own-client',
                  'senderId': 'guest',
                  'content': 'Buluşmaya geliyorum.',
                  'sentAt': now
                      .subtract(const Duration(seconds: 1))
                      .toIso8601String(),
                }),
                TableGroupMessageModel.fromWireJson(original),
                TableGroupMessageModel.fromWireJson({
                  ...original,
                  'messageId': 'system-event',
                  'clientMessageId': null,
                  'messageType': 'SYSTEM',
                  'content': 'Üye masaya katıldı.',
                  'sentAt': now
                      .add(const Duration(seconds: 1))
                      .toIso8601String(),
                }),
              ],
            ),
            gameRepository: const _NoActiveGameRepository(),
            tokenStore: const _UserTokenStore('guest'),
            realtimeClient: TableGroupChatRealtimeClient(
              transportFactory: transport.create,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mesaj seçenekleri'), findsOneWidget);
      for (final neighbor in ['Buluşmaya geliyorum.', 'Üye masaya katıldı.']) {
        await tester.longPress(find.text(neighbor));
        await tester.pumpAndSettle();
        expect(find.text('Bildirim nedeni'), findsNothing);
      }
      await tester.longPress(find.text('Yer için ödeme istendi.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Para talebi'));
      await tester.enterText(find.byType(TextFormField), 'Ödeme istedi.');
      await tester.ensureVisible(find.text('Bildirimi gönder'));
      await tester.tap(find.text('Bildirimi gönder'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tekrar dene'));
      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();
      expect(api.requests, hasLength(2));
      expect(api.requests.first.body, api.requests.last.body);
      expect(api.lastRequest.body, containsPair('messageId', 'server-msg'));
      expect(
        api.lastRequest.body.toString(),
        isNot(contains('Buluşmaya geliyorum.')),
      );
      expect(
        api.lastRequest.body.toString(),
        isNot(contains('Üye masaya katıldı.')),
      );
      expect(
        api.lastRequest.body,
        containsPair('description', 'Ödeme istedi.'),
      );
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      final channel = transport.latest!.subscriptions.keys.singleWhere(
        (k) => k.contains('g-1'),
      );
      transport.latest!.deliver(
        channel,
        jsonEncode({
          ...original,
          'deletedAt': now.toIso8601String(),
          'content': 'Bu mesaj kaldırıldı.',
        }),
      );
      transport.latest!.deliver(channel, jsonEncode(original));
      await tester.pumpAndSettle();
      expect(find.text('Bu mesaj kaldırıldı.'), findsOneWidget);
      expect(find.text('Yer için ödeme istendi.'), findsNothing);
      expect(find.text('Buluşmaya geliyorum.'), findsOneWidget);
      expect(find.text('Üye masaya katıldı.'), findsOneWidget);
      expect(find.byTooltip('Mesaj seçenekleri'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
