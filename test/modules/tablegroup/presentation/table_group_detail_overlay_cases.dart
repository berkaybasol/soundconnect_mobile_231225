part of 'table_group_detail_lifecycle_test.dart';

void _registerTableRemovalOverlayCases() {
  for (final overlay in [
    'description',
    'report',
    'game',
    'confirmation',
    'menu',
  ]) {
    testWidgets('table removal dismisses the owned $overlay route', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 11, 24);
      final sessions = AudienceTestSessions(audienceSession(user: 'guest'));
      final transport = _ImmediateTransportHarness();
      final personal = NotificationRealtimeClient(
        transportFactory: transport.create,
      );
      serviceLocator.registerSingleton<NotificationRealtimeClient>(personal);
      final api = RecordingApiClient(
        (_) => throw StateError('Unexpected report submission'),
      );
      serviceLocator.registerSingleton<TableGroupReportRepository>(
        TableGroupReportRepository(api, sessions),
      );
      addTearDown(() async {
        await personal.dispose();
        await serviceLocator.reset();
      });
      await personal.connect(userId: 'guest', token: 'fixture');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: TableGroupDetailScreen(
            args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
            sessions: sessions,
            now: () => now,
            repository: _DetailRepository(
              group: _group(
                status: 'ACTIVE',
                expiresAt: now.add(const Duration(hours: 1)),
                includeGuest: true,
                description: 'Kaldırılan özgün masa içeriği',
              ),
            ),
            gameRepository: const _NoActiveGameRepository(),
            tokenStore: const _UserTokenStore('guest'),
            realtimeClient: TableGroupChatRealtimeClient(
              transportFactory: _ImmediateTransportHarness().create,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Finder overlayContent;
      switch (overlay) {
        case 'description':
          await tester.tap(
            find.byKey(const Key('table_group_description_card')),
          );
          overlayContent = find.byKey(
            const Key('table_group_description_dialog_text'),
          );
        case 'game':
          await tester.tap(find.byKey(const Key('table-group-game-launcher')));
          overlayContent = find.text('Taş Kağıt Makas');
        default:
          await tester.tap(find.byKey(const Key('table_group_detail_more')));
          await tester.pumpAndSettle();
          if (overlay == 'report') {
            await tester.tap(find.text('Masayı bildir'));
            overlayContent = find.text('Bildirimi gönder');
          } else if (overlay == 'confirmation') {
            await tester.tap(find.text('Masadan ayrıl'));
            overlayContent = find.text('Ayrıl');
          } else {
            overlayContent = find.text('Masadan ayrıl');
          }
      }
      await tester.pumpAndSettle();
      expect(overlayContent, findsOneWidget);
      if (overlay == 'description') {
        unawaited(
          showDialog<void>(
            context: navigator.currentState!.overlay!.context,
            builder: (_) =>
                const AlertDialog(title: Text('Başka ekranın diyaloğu')),
          ),
        );
        await tester.pumpAndSettle();
      }
      final channel = transport.latest!.subscriptions.keys.singleWhere(
        (key) => key.endsWith('notifications.guest'),
      );
      transport.latest!.deliver(
        channel,
        jsonEncode({
          'id': 'notice',
          'type': 'TABLE_CANCELLED',
          'recipientId': 'guest',
          'payload': {
            'module': 'TABLE',
            'action': 'CANCELLED',
            'reason': 'ADMIN_REMOVED',
            'tableGroupId': 'g-1',
          },
        }),
      );
      await tester.pumpAndSettle();
      if (overlay == 'description') {
        expect(find.text('Başka ekranın diyaloğu'), findsOneWidget);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
      }
      expect(overlayContent, findsNothing);
      expect(find.text('Kaldırılan özgün masa içeriği'), findsNothing);
      expect(find.text('Bu masa yayından kaldırıldı.'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isFalse);
      expect(api.requests, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
