part of 'table_group_detail_lifecycle_test.dart';

void _registerTableGroupDetailLifecycle1() {
  for (final scenario in [
    (user: 'owner', role: 'ROLE_LISTENER', eligible: true),
    (user: 'guest', role: 'ROLE_LISTENER', eligible: true),
    (user: 'pending-user', role: 'ROLE_LISTENER', eligible: false),
    (user: 'outsider', role: 'ROLE_LISTENER', eligible: false),
    (user: 'owner', role: 'ROLE_MUSICIAN', eligible: false),
  ]) {
    for (final chat in [false, true]) {
      testWidgets(
        'profile share stays in ${chat ? 'chat' : 'overview'} overflow for ${scenario.user}/${scenario.role}',
        (tester) async {
          final sessions = AudienceTestSessions(
            audienceSession(user: scenario.user, role: scenario.role),
          );
          addTearDown(sessions.dispose);
          final now = DateTime.utc(2026, 9, 10, 18);
          final tokens = _UserTokenStore(scenario.user);
          await serviceLocator.reset();
          serviceLocator.registerSingleton<DmBadgeCubit>(
            DmBadgeCubit(
              _DetailDmRepository(),
              tokens,
              realtimeClient: _DetailNoopDmRealtimeClient(),
            ),
            dispose: (cubit) => cubit.close(),
          );
          addTearDown(serviceLocator.reset);
          TableGroupProfileDraftArgs? opened;
          await tester.pumpWidget(
            MaterialApp(
              onGenerateRoute: (settings) {
                if (settings.name != AppRoutes.listenerProfile) return null;
                opened = settings.arguments as TableGroupProfileDraftArgs;
                return MaterialPageRoute<void>(
                  builder: (_) => const Scaffold(body: Text('Profile draft')),
                );
              },
              home: TableGroupDetailScreen(
                args: TableGroupDetailArgs(tableGroupId: 'g-1', openChat: chat),
                repository: _DetailRepository(
                  group: _group(
                    status: 'ACTIVE',
                    expiresAt: now.add(const Duration(hours: 2)),
                    includeGuest: true,
                    includePending: true,
                  ),
                ),
                gameRepository: const _NoActiveGameRepository(),
                tokenStore: tokens,
                realtimeClient: TableGroupChatRealtimeClient(
                  transportFactory: _ImmediateTransportHarness().create,
                ),
                sessions: sessions,
                now: () => now,
                canCreateOrJoin: () => true,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Paylaş'), findsNothing);
          await tester.tap(find.byKey(const Key('table_group_detail_more')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('table_group_profile_share')),
            scenario.eligible ? findsOneWidget : findsNothing,
          );
          if (scenario.eligible) {
            await tester.tap(find.text('Paylaş'));
            await tester.pumpAndSettle();
            expect(opened?.tableGroupId, 'g-1');
            expect(opened?.expectedSession, same(sessions.session));
            expect(find.text('Profile draft'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        },
      );
    }
  }

  for (final invalidation in ['expiry', 'relogin']) {
    testWidgets('open share menu cannot outlive $invalidation', (tester) async {
      var now = DateTime.utc(2026, 9, 10, 18);
      final sessions = AudienceTestSessions(audienceSession(user: 'owner'));
      addTearDown(sessions.dispose);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            opened = true;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Unexpected draft')),
            );
          },
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
            realtimeClient: TableGroupChatRealtimeClient(
              transportFactory: _ImmediateTransportHarness().create,
            ),
            sessions: sessions,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('table_group_detail_more')));
      await tester.pumpAndSettle();
      expect(find.text('Paylaş'), findsOneWidget);
      if (invalidation == 'expiry') {
        now = now.add(const Duration(hours: 2));
      } else {
        sessions.replace(audienceSession(user: 'owner', token: 'new-login'));
      }
      await tester.tap(find.text('Paylaş'));
      await tester.pumpAndSettle();
      expect(opened, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  group('table-group lifecycle contract', () {
    test('requires ACTIVE status and a strictly future expiry', () {
      final now = DateTime.utc(2026, 8, 17, 18);

      expect(
        isTableGroupSessionActiveAt(
          _group(
            status: 'ACTIVE',
            expiresAt: now.add(const Duration(seconds: 1)),
          ),
          now,
        ),
        isTrue,
      );
      expect(
        isTableGroupSessionActiveAt(
          _group(status: 'ACTIVE', expiresAt: now),
          now,
        ),
        isFalse,
      );
      expect(
        isTableGroupSessionActiveAt(
          _group(
            status: 'CANCELLED',
            expiresAt: now.add(const Duration(hours: 1)),
          ),
          now,
        ),
        isFalse,
      );
      expect(
        isTableGroupSessionActiveAt(
          _group(status: 'ACTIVE', expiresAt: null),
          now,
        ),
        isFalse,
      );
    });

    test('strict network decoder rejects a missing sentAt instant', () {
      expect(
        () => TableGroupMessageModel.fromWireJson(<String, dynamic>{
          'messageId': 'm-1',
          'tableGroupId': 'g-1',
          'senderId': 'u-1',
          'content': 'hello',
          'messageType': 'TEXT',
          'sentAt': null,
        }),
        throwsFormatException,
      );
    });
  });

  testWidgets('cancelled detail is read-only and skips chat transports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 8, 17, 18);
    final description = List<String>.filled(
      4,
      'Kapanmış masanın açıklaması güvenli ve okunabilir kalmalı.',
    ).join(' ');
    final repository = _DetailRepository(
      group: _group(
        status: 'CANCELLED',
        expiresAt: now.add(const Duration(hours: 1)),
        description: '  $description  ',
        venueName: null,
      ),
    );
    var transportCreations = 0;
    final realtimeClient = TableGroupChatRealtimeClient(
      transportFactory: (_) {
        transportCreations += 1;
        throw StateError('Closed detail must not create a transport');
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
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
          realtimeClient: realtimeClient,
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu masa kapatildi'), findsOneWidget);
    expect(find.text('Mesaj yaz'), findsNothing);
    expect(find.text('Oturumu Sonlandir'), findsNothing);
    final venue = find.byKey(const Key('table_group_closed_venue'));
    expect(venue, findsOneWidget);
    expect(
      find.descendant(of: venue, matching: find.text('Belirtilmemiş')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: venue,
        matching: find.byIcon(Icons.storefront_outlined),
      ),
      findsOneWidget,
    );
    final preview = tester.widget<Text>(
      find.byKey(const Key('table_group_description')),
    );
    expect(preview.data, description);
    expect(preview.maxLines, 3);
    expect(preview.overflow, TextOverflow.ellipsis);
    expect(repository.chatCalls, 0);
    expect(transportCreations, 0);
    expect(tester.takeException(), isNull);

    final descriptionCard = find.byKey(
      const Key('table_group_description_card'),
    );
    await tester.ensureVisible(descriptionCard);
    await tester.pumpAndSettle();
    await tester.tap(descriptionCard);
    await tester.pumpAndSettle();
    final descriptionScheme = Theme.of(
      tester.element(
        find.byKey(const Key('table_group_description_dialog_text')),
      ),
    ).colorScheme;
    expect(descriptionScheme.brightness, Brightness.dark);
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('table_group_description_dialog_text')),
          )
          .data,
      description,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('table_group_description_dialog_text')),
          )
          .style
          ?.color,
      descriptionScheme.onSurface,
    );
    expect(find.text('Kapat'), findsOneWidget);
    await tester.tap(find.byKey(const Key('table_group_description_close')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('table_group_description_dialog_text')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'forbidden identity cannot see or race-call the detail join action',
    (tester) async {
      final now = DateTime.utc(2026, 8, 17, 18);
      final repository = _DetailRepository(
        group: _group(
          status: 'ACTIVE',
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );
      var mutationAllowed = true;
      final realtimeClient = TableGroupChatRealtimeClient(
        transportFactory: (_) =>
            throw StateError('Outsider must not connect to table chat'),
      );

      Widget app() => MaterialApp(
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _UserTokenStore('venue-user'),
          realtimeClient: realtimeClient,
          now: () => now,
          canCreateOrJoin: () => mutationAllowed,
        ),
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Katıl'), findsOneWidget);

      // Simulate the session changing after the button was rendered but before
      // the tap reached the mutation boundary.
      mutationAllowed = false;
      await tester.tap(find.text('Katıl'));
      await tester.pump();

      expect(repository.joinCalls, 0);
      expect(find.text('Katılma isteği'), findsNothing);
      expect(
        find.text(
          'Masa oluşturma ve katılma işlemleri kişisel hesaplarla kullanılabilir.',
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Katıl'), findsNothing);
      expect(repository.joinCalls, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('focused join note can be cancelled without lifecycle errors', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 17, 18);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
      ),
    );
    final realtimeClient = TableGroupChatRealtimeClient(
      transportFactory: (_) =>
          throw StateError('Outsider must not connect to table chat'),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: TableGroupDetailScreen(
          args: const TableGroupDetailArgs(tableGroupId: 'g-1'),
          repository: repository,
          gameRepository: const _NoActiveGameRepository(),
          tokenStore: const _UserTokenStore('guest'),
          realtimeClient: realtimeClient,
          now: () => now,
          canCreateOrJoin: () => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();
    final noteInput = find.byKey(const Key('table_group_join_note_input'));
    expect(noteInput, findsOneWidget);
    final joinScheme = Theme.of(tester.element(noteInput)).colorScheme;
    expect(joinScheme.brightness, Brightness.dark);
    final warning = find.byKey(const Key('table_group_join_owner_warning'));
    expect(warning, findsOneWidget);
    expect(
      find.text('Aktif bir masan varsa bu istek onaylandığında kapanır.'),
      findsOneWidget,
    );
    final warningDecoration =
        tester.widget<Container>(warning).decoration! as BoxDecoration;
    final warningGradient = warningDecoration.gradient! as LinearGradient;
    expect(warningDecoration.color, isNull);
    expect(warningGradient.colors, <Color>[
      AppColors.brandGradient.first.withValues(alpha: 0.18),
      AppColors.brandGradient.last.withValues(alpha: 0.14),
    ]);
    final warningBorder = warningDecoration.border! as Border;
    expect(
      warningBorder.top.color,
      AppColors.coralLight.withValues(alpha: 0.55),
    );
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: warning,
              matching: find.byIcon(Icons.warning_amber_rounded),
            ),
          )
          .color,
      AppColors.coralLight,
    );
    expect(
      tester.widget<Text>(find.text('Katılma isteği')).style?.color,
      joinScheme.onSurface,
    );
    expect(
      tester
          .widget<Text>(find.text('Masa sahibine kısa bir not bırakabilirsin.'))
          .style
          ?.color,
      joinScheme.onSurfaceVariant,
    );
    expect(
      tester.widget<TextField>(noteInput).style?.color,
      joinScheme.onSurface,
    );

    await tester.tap(noteInput);
    await tester.enterText(noteInput, 'Bu akşam katılmak isterim.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('table_group_join_cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('table_group_join_dialog')), findsNothing);
    expect(repository.joinCalls, 0);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('active detail shows a bounded description with full dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime.utc(2026, 8, 17, 18);
    final description = List<String>.filled(
      4,
      'Yeni insanlarla tanışıp akşam planını birlikte yapacağız.',
    ).join(' ');
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        expiresAt: now.add(const Duration(hours: 1)),
        description: description,
      ),
    );
    final realtimeClient = TableGroupChatRealtimeClient(
      transportFactory: (_) =>
          throw StateError('Outsider must not connect to table chat'),
    );

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
          tokenStore: const _UserTokenStore('viewer'),
          realtimeClient: realtimeClient,
          now: () => now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(
      find.byKey(const Key('table_group_description')),
    );
    expect(text.data, description);
    expect(text.maxLines, 3);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);

    final descriptionCard = find.byKey(
      const Key('table_group_description_card'),
    );
    await tester.ensureVisible(descriptionCard);
    await tester.pumpAndSettle();
    await tester.tap(descriptionCard);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('table_group_description_dialog_text')),
          )
          .data,
      description,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'overview renders meeting time independently from lifecycle expiry',
    (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 8, 17, 18);
      final meetingAt = DateTime(2026, 8, 17, 21, 37);
      final expiresAt = DateTime(2026, 8, 18, 18);
      final repository = _DetailRepository(
        group: _group(
          status: 'ACTIVE',
          meetingAt: meetingAt,
          expiresAt: expiresAt,
          description: 'Akşam dışarı çıkacağım, katılmak isteyen var mı?',
          venueName: null,
          includeGuest: true,
          maxPersonCount: 4,
        ),
      );
      var transportCreations = 0;
      final realtimeClient = TableGroupChatRealtimeClient(
        transportFactory: (_) {
          transportCreations += 1;
          throw StateError('Overview must not connect an outsider to chat');
        },
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

      final meeting = find.byKey(const Key('table_group_detail_meeting_time'));
      expect(
        find.descendant(of: meeting, matching: find.text('Bugün 21:37')),
        findsOneWidget,
      );
      expect(find.text('18:00'), findsNothing);
      final venue = find.byKey(const Key('table_group_detail_venue'));
      expect(venue, findsOneWidget);
      expect(
        find.descendant(of: venue, matching: find.text('Belirtilmemiş')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: venue, matching: find.byType(FittedBox)),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_detail_capacity_slots')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_detail_stats_inline')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_detail_stats_stacked')),
        findsNothing,
      );
      expect(
        tester
            .getSize(find.byKey(const Key('table_group_detail_summary')))
            .height,
        inInclusiveRange(200, 214),
      );
      expect(
        find.byKey(const Key('table_group_detail_participant-owner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_detail_participant-guest')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_detail_empty_participant-0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('table_group_detail_empty_participant-1')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(
              find.byKey(const Key('table_group_detail_participant-owner')),
            )
            .height,
        closeTo(56, 0.1),
      );
      expect(
        tester
            .getSize(
              find.byKey(const Key('table_group_detail_empty_participant-0')),
            )
            .height,
        closeTo(38, 0.1),
      );
      expect(find.text('2/4'), findsOneWidget);
      expect(find.text('Katıl'), findsOneWidget);
      expect(repository.chatCalls, 0);
      expect(transportCreations, 0);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('detail meeting day refreshes across local midnight', (
    tester,
  ) async {
    var now = DateTime(2026, 9, 2, 23, 59, 59);
    final repository = _DetailRepository(
      group: _group(
        status: 'ACTIVE',
        meetingAt: DateTime(2026, 9, 3, 9),
        expiresAt: DateTime(2026, 9, 3, 23),
      ),
    );
    final realtimeClient = TableGroupChatRealtimeClient(
      transportFactory: (_) =>
          throw StateError('Overview viewer must not connect to chat'),
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
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yarın 09:00'), findsOneWidget);

    now = DateTime(2026, 9, 3, 0, 0, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Bugün 09:00'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
