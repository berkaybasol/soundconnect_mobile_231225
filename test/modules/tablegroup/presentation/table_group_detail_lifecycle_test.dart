import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart'
    as pagination;
import 'package:soundconnect_23_12_25codx/core/realtime/stomp_realtime_transport.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/data/dm_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_create_request.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_message_model.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_chat_realtime_client.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_game.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_message.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_participant.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_lifecycle.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_game_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/screens/table_group_detail_screen.dart';

void main() {
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
        find.descendant(of: meeting, matching: find.text('21:37')),
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
      '/topic/table_group/g-1',
      jsonEncode(<String, dynamic>{
        'messageId': 'from-realtime',
        'tableGroupId': 'g-1',
        'senderId': 'another-user',
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

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
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

    transport.latest!.deliver('/topic/table_group/g-1', '[]');
    await tester.pump();
    expect(
      find.text('Canli sohbetten gecersiz bir mesaj alindi.'),
      findsOneWidget,
    );

    transport.latest!.deliver(
      '/topic/table_group/g-1',
      jsonEncode(<String, dynamic>{
        'messageId': 'valid-after-invalid',
        'tableGroupId': 'g-1',
        'senderId': 'another-user',
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

    transport.latest!.deliver('/topic/table_group/g-1', '[]');
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

TableGroupMessage _expiringGameMessage({
  required DateTime now,
  required DateTime deadline,
}) {
  return TableGroupMessageModel.fromWireJson(<String, dynamic>{
    'messageId': 'game-message-1',
    'tableGroupId': 'g-1',
    'senderId': 'owner',
    'content': 'Hesap Kimde oyunu',
    'messageType': 'GAME',
    'sentAt': now.toIso8601String(),
    'deletedAt': null,
    'game': <String, dynamic>{
      'schemaVersion': 1,
      'gameId': 'game-1',
      'tableGroupId': 'g-1',
      'revision': 1,
      'topic': 'WHO_PAYS',
      'mode': 'DICE',
      'status': 'IN_PROGRESS',
      'phase': 'DICE',
      'createdBy': 'owner',
      'createdByUsername': 'Owner',
      'round': 1,
      'joinDeadlineAt': null,
      'actionDeadlineAt': deadline.toIso8601String(),
      'serverTime': now.toIso8601String(),
      'players': <Object?>[
        <String, dynamic>{
          'userId': 'owner',
          'username': 'Owner',
          'status': 'ACTIVE',
          'joinedAt': now.toIso8601String(),
          'hasActed': false,
        },
      ],
      'revealedActions': <Object?>[],
      'selectedUserId': null,
      'selectedUsername': null,
      'outcome': null,
      'resultMessage': null,
      'cancellationReason': null,
    },
  });
}

TableGroup _group({
  required String status,
  required DateTime? expiresAt,
  DateTime? meetingAt,
  String? description,
  String? venueName = 'Test Mekani',
  bool includeGuest = false,
  bool includePending = false,
  int extraPendingCount = 0,
  int maxPersonCount = 4,
}) {
  return TableGroup(
    id: 'g-1',
    ownerId: 'owner',
    ownerUsername: 'Owner',
    ownerProfileImageUrl: null,
    venueId: null,
    venueName: venueName,
    description: description,
    maxPersonCount: maxPersonCount,
    genderPrefs: const <String>[],
    ageMin: 18,
    ageMax: 99,
    meetingAt: meetingAt,
    expiresAt: expiresAt,
    status: status,
    participants: <TableGroupParticipant>[
      const TableGroupParticipant(
        userId: 'owner',
        joinedAt: null,
        status: TableGroupParticipantStatus.accepted,
        joinNote: null,
        username: 'Owner',
        profilePictureUrl: null,
      ),
      if (includeGuest)
        const TableGroupParticipant(
          userId: 'guest',
          joinedAt: null,
          status: TableGroupParticipantStatus.accepted,
          joinNote: null,
          username: 'Guest',
          profilePictureUrl: null,
        ),
      if (includePending)
        const TableGroupParticipant(
          userId: 'pending-user',
          joinedAt: null,
          status: TableGroupParticipantStatus.pending,
          joinNote: '21:00 gibi oradayim',
          username: 'Pending User',
          profilePictureUrl: null,
        ),
      for (var index = 0; index < extraPendingCount; index += 1)
        TableGroupParticipant(
          userId: 'pending-extra-$index',
          joinedAt: null,
          status: TableGroupParticipantStatus.pending,
          joinNote: 'Ek katilim notu $index',
          username: 'Pending Extra $index',
          profilePictureUrl: null,
        ),
    ],
    city: const TableGroupLocation(id: 'city-1', name: 'Istanbul'),
    district: const TableGroupLocation(id: 'district-1', name: 'Kadikoy'),
    neighborhood: null,
  );
}

class _DetailRepository implements TableGroupRepository {
  _DetailRepository({
    required this.group,
    this.messages = const <TableGroupMessage>[],
  });

  final TableGroup group;
  final List<TableGroupMessage> messages;
  int chatCalls = 0;
  int kickCalls = 0;
  int joinCalls = 0;
  String? lastKickedParticipantId;
  Completer<Result<pagination.Page<TableGroupMessage>>>? nextChatResponse;

  @override
  Future<Result<TableGroup>> getDetail(String tableGroupId) async =>
      Result.success(group);

  @override
  Future<Result<pagination.Page<TableGroupMessage>>> getChatMessages({
    required String tableGroupId,
    int page = 0,
    int size = 30,
  }) async {
    chatCalls += 1;
    final blocked = nextChatResponse;
    if (blocked != null) {
      nextChatResponse = null;
      return blocked.future;
    }
    return Result.success(
      pagination.Page<TableGroupMessage>(items: messages, hasNext: false),
    );
  }

  @override
  Future<Result<void>> approveJoinRequest({
    required String tableGroupId,
    required String participantId,
  }) async => const Result.success(null);

  @override
  Future<Result<void>> cancelTableGroup({required String tableGroupId}) async =>
      const Result.success(null);

  @override
  Future<Result<TableGroup>> createTableGroup(
    TableGroupCreateRequest request,
  ) async => Result.success(group);

  @override
  Future<Result<int>> getUnreadBadge({required String tableGroupId}) async =>
      const Result.success(0);

  @override
  Future<Result<void>> joinTableGroup({
    required String tableGroupId,
    String? note,
  }) async {
    joinCalls += 1;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> kickParticipant({
    required String tableGroupId,
    required String participantId,
  }) async {
    kickCalls += 1;
    lastKickedParticipantId = participantId;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> leaveTableGroup({required String tableGroupId}) async =>
      const Result.success(null);

  @override
  Future<Result<pagination.Page<TableGroup>>> listActiveTableGroups({
    required String? cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  }) async => const Result.success(
    pagination.Page<TableGroup>(items: <TableGroup>[], hasNext: false),
  );

  @override
  Future<Result<void>> rejectJoinRequest({
    required String tableGroupId,
    required String participantId,
  }) async => const Result.success(null);

  @override
  Future<Result<TableGroupMessage>> sendChatMessage({
    required String tableGroupId,
    required String content,
    String messageType = 'TEXT',
  }) async => Result.success(
    TableGroupMessage(
      messageId: 'm-1',
      tableGroupId: tableGroupId,
      senderId: 'owner',
      content: content,
      messageType: messageType,
      sentAt: DateTime.now().toUtc(),
      deletedAt: null,
    ),
  );
}

class _ExpiryGameRepository extends _NoActiveGameRepository {
  _ExpiryGameRepository(this.activeMessage);

  final TableGroupMessage activeMessage;
  int activeCalls = 0;
  int detailCalls = 0;

  @override
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  }) async {
    activeCalls += 1;
    return Result<TableGroupMessage?>.success(activeMessage);
  }

  @override
  Future<Result<TableGroupMessage>> getGame({
    required String tableGroupId,
    required String gameId,
  }) async {
    detailCalls += 1;
    return const Result<TableGroupMessage>.failure(
      AppError(code: 'network', message: 'Temporary failure'),
    );
  }
}

class _NoActiveGameRepository implements TableGroupGameRepository {
  const _NoActiveGameRepository();

  static const _unavailable = Result<TableGroupMessage>.failure(
    AppError(code: 'test', message: 'Unavailable in this test'),
  );

  @override
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  }) async => const Result<TableGroupMessage?>.success(null);

  @override
  Future<Result<TableGroupMessage>> getGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> createGame({
    required String tableGroupId,
    required String requestId,
    required TableGroupGameMode mode,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> joinGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> leaveGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> startGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> cancelGame({
    required String tableGroupId,
    required String gameId,
  }) async => _unavailable;

  @override
  Future<Result<TableGroupMessage>> submitAction({
    required String tableGroupId,
    required String gameId,
    required String requestId,
    required TableGroupGameAction action,
    String? targetUserId,
  }) async => _unavailable;
}

class _OwnerTokenStore implements TokenStore {
  const _OwnerTokenStore();

  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async => 'e30.eyJzdWIiOiJvd25lciJ9.signature';

  @override
  Future<void> writeToken(String token) async {}
}

class _DetailDmRepository extends Fake implements DmRepository {
  @override
  Future<Result<int>> getUnreadCount() async => const Result.success(0);
}

class _DetailNoopDmRealtimeClient extends DmRealtimeClient {
  @override
  Stream<int> get badgeStream => const Stream<int>.empty();

  @override
  Future<void> connect({required String userId, required String token}) async {}

  @override
  Future<void> disconnect() async {}

  @override
  void retain() {}

  @override
  Future<void> release() async {}
}

class _UserTokenStore implements TokenStore {
  const _UserTokenStore(this.userId);

  final String userId;

  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async {
    final payload = base64Url
        .encode(utf8.encode(jsonEncode(<String, String>{'sub': userId})))
        .replaceAll('=', '');
    return 'e30.$payload.signature';
  }

  @override
  Future<void> writeToken(String token) async {}
}

class _ImmediateTransportHarness {
  int created = 0;
  _ImmediateTransport? latest;

  RealtimeTransport create(RealtimeTransportConfig config) {
    created += 1;
    final transport = _ImmediateTransport(config);
    latest = transport;
    return transport;
  }
}

class _ImmediateTransport implements RealtimeTransport {
  _ImmediateTransport(this.config);

  final RealtimeTransportConfig config;
  final Map<String, RealtimeMessageCallback> subscriptions =
      <String, RealtimeMessageCallback>{};
  bool deactivated = false;

  @override
  void activate() => config.onConnect();

  @override
  void deactivate() {
    deactivated = true;
  }

  @override
  void send({required String destination, required String body}) {}

  void deliver(String destination, String body) {
    final callback = subscriptions[destination];
    if (callback == null) throw StateError('Missing $destination subscription');
    callback(body);
  }

  @override
  void subscribe({
    required String destination,
    required RealtimeMessageCallback callback,
  }) {
    subscriptions[destination] = callback;
  }
}
