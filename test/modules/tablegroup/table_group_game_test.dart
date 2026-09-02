import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/models/table_group_message_model.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_game_endpoints.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/data/table_group_game_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_game.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_message.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_game_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/table_group_message_timeline.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/cubit/table_group_game_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/table_group_game_copy.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/widgets/table_group_game_countdown.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/widgets/table_group_game_launcher_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/widgets/table_group_game_message_card.dart';

void main() {
  group('table-group game wire model', () {
    test('decodes typed game snapshot and normalizes instants to UTC', () {
      final message = TableGroupMessageModel.fromWireJson(
        _gameMessageJson(
          mode: 'VOTE',
          phase: 'COMPLETED',
          status: 'COMPLETED',
          outcome: 'VOLUNTEER',
          revealedActions: <Object?>[
            <String, dynamic>{
              'round': 1,
              'phase': 'VOTE',
              'actorUserId': 'owner',
              'action': 'VOLUNTEER',
              'targetUserId': 'owner',
              'value': null,
            },
          ],
        ),
      );

      expect(message.messageType, 'GAME');
      expect(message.game?.mode, TableGroupGameMode.vote);
      expect(message.game?.phase, TableGroupGamePhase.completed);
      expect(message.game?.outcome, TableGroupGameOutcome.volunteer);
      expect(message.game?.serverTime?.isUtc, isTrue);
      expect(
        message.game?.players.single.status,
        TableGroupGamePlayerStatus.active,
      );
      expect(message.game?.revealedActions.single.action, 'VOLUNTEER');
    });

    test('rejects a game payload belonging to another table', () {
      final payload = _gameMessageJson();
      (payload['game'] as Map<String, dynamic>)['tableGroupId'] = 'other';

      expect(
        () => TableGroupMessageModel.fromWireJson(payload),
        throwsFormatException,
      );
    });

    test('rejects revision zero', () {
      expect(
        () =>
            TableGroupMessageModel.fromWireJson(_gameMessageJson(revision: 0)),
        throwsFormatException,
      );
    });

    test('rejects a nested game payload on a non-game message', () {
      final payload = _gameMessageJson()..['messageType'] = 'TEXT';

      expect(
        () => TableGroupMessageModel.fromWireJson(payload),
        throwsFormatException,
      );
    });

    test('rejects fractional revisions and non-boolean action flags', () {
      final fractional = _gameMessageJson();
      (fractional['game'] as Map<String, dynamic>)['revision'] = 1.5;
      expect(
        () => TableGroupMessageModel.fromWireJson(fractional),
        throwsFormatException,
      );

      final invalidFlag = _gameMessageJson();
      final players =
          (invalidFlag['game'] as Map<String, dynamic>)['players']
              as List<Object?>;
      (players.single as Map<String, dynamic>)['hasActed'] = 'true';
      expect(
        () => TableGroupMessageModel.fromWireJson(invalidFlag),
        throwsFormatException,
      );

      final duplicatePlayer = _gameMessageJson(
        players: <Object?>[
          _player('owner', 'ece'),
          _player('owner', 'ece-again'),
        ],
      );
      expect(
        () => TableGroupMessageModel.fromWireJson(duplicatePlayer),
        throwsFormatException,
      );
    });

    test('marks a contradictory mode and phase as non-interactive', () {
      final message = _gameMessage(
        mode: 'DICE',
        status: 'IN_PROGRESS',
        phase: 'RPS',
      );

      expect(message.game?.supportsWhoPaysInteraction, isFalse);
    });
  });

  group('game-aware chat timeline', () {
    test('never lets a lower game revision replace a newer card', () {
      final revisionThree = _gameMessage(revision: 3);
      final revisionTwo = _gameMessage(revision: 2);

      final merged = mergeTableGroupMessagesChronologically(
        existing: <TableGroupMessage>[revisionThree],
        incoming: <TableGroupMessage>[revisionTwo],
      );

      expect(merged.single.game?.revision, 3);
      expect(isNewerTableGroupGameMessage(revisionThree, revisionTwo), isTrue);
      expect(isNewerTableGroupGameMessage(revisionTwo, revisionThree), isFalse);
    });

    test('equal revision keeps the fresher server snapshot', () {
      final realtime = _gameMessage(
        revision: 3,
        serverTime: '2026-08-30T18:01:00Z',
      );
      final staleHistory = _gameMessage(
        revision: 3,
        serverTime: '2026-08-30T18:00:00Z',
      );

      final merged = mergeTableGroupMessagesChronologically(
        existing: <TableGroupMessage>[realtime],
        incoming: <TableGroupMessage>[staleHistory],
      );

      expect(merged.single.game?.serverTime, DateTime.utc(2026, 8, 30, 18, 1));
      expect(isFresherTableGroupGameMessage(realtime, staleHistory), isTrue);
    });
  });

  group('TableGroupGameRepositoryImpl', () {
    test('uses exact create and volunteer action contracts', () async {
      final api = _RecordingApiClient(_gameMessageJson(mode: 'VOTE'));
      final repository = TableGroupGameRepositoryImpl(api);

      final created = await repository.createGame(
        tableGroupId: 'g-1',
        requestId: 'request-create',
        mode: TableGroupGameMode.vote,
      );
      expect(created.isSuccess, isTrue);
      expect(api.path, TableGroupGameEndpoints.games('g-1'));
      expect(api.body, <String, dynamic>{
        'requestId': 'request-create',
        'mode': 'VOTE',
      });

      await repository.submitAction(
        tableGroupId: 'g-1',
        gameId: 'game-1',
        requestId: 'request-action',
        action: TableGroupGameAction.volunteer,
      );
      expect(api.path, TableGroupGameEndpoints.actions('g-1', 'game-1'));
      expect(api.body, <String, dynamic>{
        'requestId': 'request-action',
        'action': 'VOLUNTEER',
      });
    });

    test('accepts an empty active-game response', () async {
      final api = _RecordingApiClient(null);
      final result = await TableGroupGameRepositoryImpl(
        api,
      ).getActiveGame(tableGroupId: 'g-1');

      expect(result.isSuccess, isTrue);
      expect(result.data, isNull);
      expect(api.path, TableGroupGameEndpoints.active('g-1'));
    });

    test('rejects a vote action without a target before transport', () async {
      final api = _RecordingApiClient(_gameMessageJson(mode: 'VOTE'));
      final result = await TableGroupGameRepositoryImpl(api).submitAction(
        tableGroupId: 'g-1',
        gameId: 'game-1',
        requestId: 'request-action',
        action: TableGroupGameAction.vote,
      );

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'table_group_game_vote_target_required');
      expect(api.path, isNull);
    });

    test('maps an unknown create mode to a typed failure', () async {
      final api = _RecordingApiClient(_gameMessageJson());
      final result = await TableGroupGameRepositoryImpl(api).createGame(
        tableGroupId: 'g-1',
        requestId: 'request-create',
        mode: TableGroupGameMode.unknown,
      );

      expect(result.isSuccess, isFalse);
      expect(result.error?.code, 'table_group_game_mode_invalid');
      expect(api.path, isNull);
    });
  });

  group('TableGroupGameCubit', () {
    test('reuses request ids for failed create and action retries', () async {
      var nextId = 0;
      final repository = _GameRepositoryFake(
        createResults: <Result<TableGroupMessage>>[
          const Result.failure(AppError(code: 'network', message: 'lost')),
          const Result.failure(AppError(code: 'network', message: 'lost')),
          const Result.failure(AppError(code: 'network', message: 'lost')),
        ],
        actionResults: <Result<TableGroupMessage>>[
          const Result.failure(AppError(code: 'network', message: 'lost')),
          const Result.failure(AppError(code: 'network', message: 'lost')),
          const Result.failure(AppError(code: 'network', message: 'lost')),
        ],
      );
      final cubit = TableGroupGameCubit(
        repository: repository,
        tableGroupId: 'g-1',
        requestIdFactory: () => 'request-${++nextId}',
      );
      addTearDown(cubit.close);

      await cubit.create(TableGroupGameMode.vote);
      await cubit.create(TableGroupGameMode.vote);
      await cubit.create(TableGroupGameMode.dice);
      expect(repository.createRequestIds, <String>[
        'request-1',
        'request-1',
        'request-2',
      ]);

      cubit.acceptRealtimeMessage(
        _gameMessage(mode: 'VOTE', phase: 'VOTE', status: 'IN_PROGRESS'),
      );
      await cubit.act(gameId: 'game-1', action: TableGroupGameAction.volunteer);
      await cubit.act(gameId: 'game-1', action: TableGroupGameAction.volunteer);
      await cubit.act(
        gameId: 'game-1',
        action: TableGroupGameAction.vote,
        targetUserId: 'other',
      );
      expect(repository.actionRequestIds, <String>[
        'request-3',
        'request-3',
        'request-4',
      ]);
    });

    test(
      'a successful turn action blocks every second action in that turn',
      () async {
        final staleSuccess = _gameMessage(
          revision: 2,
          mode: 'VOTE',
          phase: 'VOTE',
          status: 'IN_PROGRESS',
          players: <Object?>[_player('owner', 'ece'), _player('other', 'mert')],
        );
        final repository = _GameRepositoryFake(
          actionResults: <Result<TableGroupMessage>>[
            Result<TableGroupMessage>.success(staleSuccess),
          ],
        );
        final cubit = TableGroupGameCubit(
          repository: repository,
          tableGroupId: 'g-1',
          requestIdFactory: () => 'request-1',
        );
        addTearDown(cubit.close);
        cubit.acceptRealtimeMessage(
          _gameMessage(
            mode: 'VOTE',
            phase: 'VOTE',
            status: 'IN_PROGRESS',
            players: <Object?>[
              _player('owner', 'ece'),
              _player('other', 'mert'),
            ],
          ),
        );

        await cubit.act(
          gameId: 'game-1',
          action: TableGroupGameAction.volunteer,
        );
        await cubit.act(
          gameId: 'game-1',
          action: TableGroupGameAction.vote,
          targetUserId: 'owner',
        );

        expect(repository.actionRequestIds, <String>['request-1']);
        expect(cubit.state.isActionCommittedFor(cubit.state.game!), isTrue);
      },
    );

    test('clear fences late active-load and action completions', () async {
      final active = Completer<Result<TableGroupMessage?>>();
      final action = Completer<Result<TableGroupMessage>>();
      final repository = _GameRepositoryFake(
        activeCompleter: active,
        actionCompleter: action,
      );
      final cubit = TableGroupGameCubit(
        repository: repository,
        tableGroupId: 'g-1',
        requestIdFactory: () => 'request',
      );
      addTearDown(cubit.close);

      final loadFuture = cubit.loadActive();
      cubit.clear();
      active.complete(Result<TableGroupMessage?>.success(_gameMessage()));
      await loadFuture;
      expect(cubit.state.message, isNull);

      cubit.acceptRealtimeMessage(
        _gameMessage(phase: 'DICE', status: 'IN_PROGRESS'),
      );
      final actionFuture = cubit.act(
        gameId: 'game-1',
        action: TableGroupGameAction.roll,
      );
      cubit.clear();
      action.complete(
        Result<TableGroupMessage>.success(_gameMessage(revision: 2)),
      );
      await actionFuture;
      expect(cubit.state.message, isNull);
      expect(cubit.state.actionInFlight, isFalse);
    });

    test('an older historical game cannot replace the current game', () {
      final cubit = TableGroupGameCubit(
        repository: _GameRepositoryFake(),
        tableGroupId: 'g-1',
      );
      addTearDown(cubit.close);
      cubit.acceptRealtimeMessage(
        _gameMessage(
          gameId: 'game-current',
          messageId: 'message-current',
          sentAt: '2026-08-30T18:05:00Z',
          status: 'IN_PROGRESS',
          phase: 'DICE',
        ),
      );

      cubit.acceptHistoryMessage(
        _gameMessage(
          gameId: 'game-old',
          messageId: 'message-old',
          sentAt: '2026-08-30T18:00:00Z',
          status: 'COMPLETED',
          phase: 'COMPLETED',
        ),
      );

      expect(cubit.state.game?.gameId, 'game-current');
    });

    test('equal-revision history cannot age the realtime game state', () {
      final cubit = TableGroupGameCubit(
        repository: _GameRepositoryFake(),
        tableGroupId: 'g-1',
      );
      addTearDown(cubit.close);
      cubit.acceptRealtimeMessage(
        _gameMessage(
          revision: 3,
          serverTime: '2026-08-30T18:01:00Z',
          status: 'IN_PROGRESS',
          phase: 'DICE',
        ),
      );

      cubit.acceptHistoryMessage(
        _gameMessage(
          revision: 3,
          serverTime: '2026-08-30T18:00:00Z',
          status: 'IN_PROGRESS',
          phase: 'DICE',
        ),
      );

      expect(cubit.state.game?.serverTime, DateTime.utc(2026, 8, 30, 18, 1));
    });

    test('a clock-skewed live active game replaces a terminal game', () {
      final cubit = TableGroupGameCubit(
        repository: _GameRepositoryFake(),
        tableGroupId: 'g-1',
      );
      addTearDown(cubit.close);
      cubit.acceptRealtimeMessage(
        _gameMessage(
          gameId: 'game-terminal',
          messageId: 'message-terminal',
          sentAt: '2026-08-30T18:05:00Z',
          status: 'COMPLETED',
          phase: 'COMPLETED',
        ),
      );

      cubit.acceptRealtimeMessage(
        _gameMessage(
          gameId: 'game-active',
          messageId: 'message-active',
          sentAt: '2026-08-30T18:00:00Z',
          status: 'IN_PROGRESS',
          phase: 'DICE',
        ),
      );

      expect(cubit.state.game?.gameId, 'game-active');
    });

    test('a live active game supersedes a clock-skewed active frame', () {
      final cubit = TableGroupGameCubit(
        repository: _GameRepositoryFake(),
        tableGroupId: 'g-1',
      );
      addTearDown(cubit.close);
      cubit.acceptRealtimeMessage(
        _gameMessage(
          gameId: 'game-old',
          messageId: 'message-old',
          sentAt: '2026-08-30T18:05:00Z',
          status: 'IN_PROGRESS',
          phase: 'DICE',
        ),
      );

      cubit.acceptRealtimeMessage(
        _gameMessage(
          gameId: 'game-current',
          messageId: 'message-current',
          sentAt: '2026-08-30T18:00:00Z',
          status: 'IN_PROGRESS',
          phase: 'DICE',
        ),
      );
      expect(cubit.state.game?.gameId, 'game-current');

      cubit.acceptRealtimeMessage(
        _gameMessage(
          gameId: 'game-old',
          messageId: 'message-old',
          sentAt: '2026-08-30T18:10:00Z',
          revision: 2,
          status: 'IN_PROGRESS',
          phase: 'DICE',
        ),
      );
      expect(cubit.state.game?.gameId, 'game-current');
    });

    test(
      'authoritative active load fences a delayed superseded game',
      () async {
        final active = Completer<Result<TableGroupMessage?>>();
        final cubit = TableGroupGameCubit(
          repository: _GameRepositoryFake(activeCompleter: active),
          tableGroupId: 'g-1',
        );
        addTearDown(cubit.close);
        cubit.acceptRealtimeMessage(
          _gameMessage(
            gameId: 'game-old',
            messageId: 'message-old',
            sentAt: '2026-08-30T18:05:00Z',
            status: 'IN_PROGRESS',
            phase: 'DICE',
          ),
        );

        final load = cubit.loadActive();
        active.complete(
          Result<TableGroupMessage?>.success(
            _gameMessage(
              gameId: 'game-current',
              messageId: 'message-current',
              sentAt: '2026-08-30T18:00:00Z',
              status: 'IN_PROGRESS',
              phase: 'DICE',
            ),
          ),
        );
        await load;
        expect(cubit.state.game?.gameId, 'game-current');

        cubit.acceptRealtimeMessage(
          _gameMessage(
            gameId: 'game-old',
            messageId: 'message-old',
            sentAt: '2026-08-30T18:10:00Z',
            revision: 2,
            status: 'IN_PROGRESS',
            phase: 'DICE',
          ),
        );
        expect(cubit.state.game?.gameId, 'game-current');
      },
    );

    test('a delayed active response cannot resurrect its old game', () async {
      final active = Completer<Result<TableGroupMessage?>>();
      final cubit = TableGroupGameCubit(
        repository: _GameRepositoryFake(activeCompleter: active),
        tableGroupId: 'g-1',
      );
      addTearDown(cubit.close);
      final oldActive = _gameMessage(
        gameId: 'game-old',
        messageId: 'message-old',
        status: 'IN_PROGRESS',
        phase: 'DICE',
      );
      cubit.acceptRealtimeMessage(oldActive);

      final load = cubit.loadActive();
      cubit.acceptRealtimeMessage(
        _gameMessage(
          gameId: 'game-old',
          messageId: 'message-old',
          revision: 2,
          status: 'COMPLETED',
          phase: 'COMPLETED',
        ),
      );
      cubit.acceptRealtimeMessage(
        _gameMessage(
          gameId: 'game-current',
          messageId: 'message-current',
          sentAt: '2026-08-30T18:00:01Z',
          status: 'IN_PROGRESS',
          phase: 'DICE',
        ),
      );
      active.complete(Result<TableGroupMessage?>.success(oldActive));
      await load;

      expect(cubit.state.game?.gameId, 'game-current');
    });

    test(
      'a delayed create response cannot replace a newer live game',
      () async {
        final create = Completer<Result<TableGroupMessage>>();
        final cubit = TableGroupGameCubit(
          repository: _GameRepositoryFake(createCompleter: create),
          tableGroupId: 'g-1',
        );
        addTearDown(cubit.close);

        final createFuture = cubit.create(TableGroupGameMode.dice);
        cubit.acceptRealtimeMessage(
          _gameMessage(
            gameId: 'game-current',
            messageId: 'message-current',
            status: 'IN_PROGRESS',
            phase: 'DICE',
          ),
        );
        create.complete(
          Result<TableGroupMessage>.success(
            _gameMessage(
              gameId: 'game-old-response',
              messageId: 'message-old-response',
              sentAt: '2026-08-30T17:59:59Z',
            ),
          ),
        );
        await createFuture;

        expect(cubit.state.game?.gameId, 'game-current');
      },
    );

    test('authoritative create replaces a locally active due game', () async {
      final repository = _GameRepositoryFake(
        createResults: <Result<TableGroupMessage>>[
          Result<TableGroupMessage>.success(
            _gameMessage(
              gameId: 'game-new',
              messageId: 'message-new',
              sentAt: '2026-08-30T18:00:00Z',
            ),
          ),
        ],
      );
      final cubit = TableGroupGameCubit(
        repository: repository,
        tableGroupId: 'g-1',
      );
      addTearDown(cubit.close);
      cubit.acceptRealtimeMessage(
        _gameMessage(
          gameId: 'game-due',
          messageId: 'message-due',
          sentAt: '2026-08-30T18:05:00Z',
          status: 'IN_PROGRESS',
          phase: 'DICE',
        ),
      );

      await cubit.create(TableGroupGameMode.dice);

      expect(cubit.state.game?.gameId, 'game-new');
    });
  });

  testWidgets('launcher offers exactly the three MVP modes', (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2.5)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showTableGroupGameLauncherSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('🎮 Hesap Kimde?'), findsOneWidget);
    expect(find.text('Taş Kağıt Makas'), findsOneWidget);
    expect(find.text('Zar'), findsOneWidget);
    expect(find.text('Oylama'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'vote card allows a normal self vote separately from volunteering',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TableGroupGameAction? selectedAction;
      String? selectedTarget;
      final message = _gameMessage(
        mode: 'VOTE',
        phase: 'VOTE',
        status: 'IN_PROGRESS',
        players: <Object?>[
          _player('owner', 'ece'),
          _player('other', 'mert', hasActed: true),
        ],
        revealedActions: <Object?>[
          <String, dynamic>{
            'round': 1,
            'phase': 'VOTE',
            'actorUserId': 'other',
            'action': 'VOTE',
            'targetUserId': 'owner',
            'value': null,
          },
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TableGroupGameMessageCard(
                message: message,
                currentUserId: 'owner',
                canCancelGame: true,
                actionInFlight: false,
                onJoin: () {},
                onLeave: () {},
                onStart: () {},
                onCancel: () {},
                onAction: (action, target) {
                  selectedAction = action;
                  selectedTarget = target;
                },
                onExpired: () {},
                now: () => DateTime.utc(2026, 8, 30, 18),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(TableGroupGameCopy.voteWarning), findsOneWidget);
      expect(find.text(TableGroupGameCopy.volunteerOption), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('game-vote-owner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('game-vote-other')),
        findsOneWidget,
      );
      expect(find.text('@mert'), findsWidgets);
      expect(find.text('@ece (sen)'), findsOneWidget);
      expect(find.text('@mert → @ece'), findsOneWidget);
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey<String>('game-player-status-other')),
            )
            .label,
        contains('@mert hamlesini yaptı'),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey<String>('game-vote-owner')));
      expect(selectedAction, TableGroupGameAction.vote);
      expect(selectedTarget, 'owner');

      await tester.tap(find.byKey(const ValueKey<String>('game-vote-other')));
      expect(selectedAction, TableGroupGameAction.vote);
      expect(selectedTarget, 'other');

      await tester.tap(
        find.byKey(const ValueKey<String>('game-action-volunteer')),
      );
      expect(selectedAction, TableGroupGameAction.volunteer);
      expect(selectedTarget, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TableGroupGameMessageCard(
                message: message,
                currentUserId: 'owner',
                canCancelGame: true,
                actionInFlight: false,
                actionCommitted: true,
                onJoin: () {},
                onLeave: () {},
                onStart: () {},
                onCancel: () {},
                onAction: (_, __) {},
                onExpired: () {},
                now: () => DateTime.utc(2026, 8, 30, 18),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Hamlen alındı. Diğer oyuncular bekleniyor.'), findsOne);
      expect(
        find.byKey(const ValueKey<String>('game-action-volunteer')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('game-vote-owner')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('completed card renders backend result message exactly', (
    tester,
  ) async {
    const result =
        'SoundConnect ve masan, sadakatini takdir ediyor! '
        '@ece hesabı gönüllü olarak üstlendi. 😎';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableGroupGameMessageCard(
            message: _gameMessage(
              mode: 'VOTE',
              phase: 'COMPLETED',
              status: 'COMPLETED',
              outcome: 'VOLUNTEER',
              resultMessage: result,
            ),
            currentUserId: 'owner',
            canCancelGame: true,
            actionInFlight: false,
            onJoin: () {},
            onLeave: () {},
            onStart: () {},
            onCancel: () {},
            onAction: (_, __) {},
            onExpired: () {},
          ),
        ),
      ),
    );

    expect(find.text(result), findsOneWidget);
  });

  testWidgets('an unsupported future game schema is rendered read-only', (
    tester,
  ) async {
    final payload = _gameMessageJson();
    (payload['game'] as Map<String, dynamic>)['schemaVersion'] = 2;
    final message = TableGroupMessageModel.fromWireJson(payload);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableGroupGameMessageCard(
            message: message,
            currentUserId: 'owner',
            canCancelGame: true,
            actionInFlight: false,
            onJoin: () {},
            onLeave: () {},
            onStart: () {},
            onCancel: () {},
            onAction: (_, __) {},
            onExpired: () {},
          ),
        ),
      ),
    );

    expect(find.text('🎮 Hesap Kimde?'), findsOneWidget);
    expect(find.textContaining('henüz desteklenmiyor'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('table-group-game-join')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('table-group-game-cancel')),
      findsNothing,
    );
  });

  testWidgets('a historical nonterminal game cannot submit actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableGroupGameMessageCard(
            message: _gameMessage(),
            currentUserId: 'owner',
            canCancelGame: true,
            actionInFlight: false,
            interactionEnabled: false,
            onJoin: () {},
            onLeave: () {},
            onStart: () {},
            onCancel: () {},
            onAction: (_, __) {},
            onExpired: () {},
          ),
        ),
      ),
    );

    expect(find.text('Bu oyun artık aktif değil.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('table-group-game-countdown')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('table-group-game-join')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('table-group-game-cancel')),
      findsNothing,
    );
  });

  testWidgets('owner table closure is rendered as friendly Turkish copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableGroupGameMessageCard(
            message: _gameMessage(
              phase: 'CANCELLED',
              status: 'CANCELLED',
              cancellationReason: 'TABLE_OWNER_JOINED_ANOTHER_TABLE',
            ),
            currentUserId: 'owner',
            canCancelGame: true,
            actionInFlight: false,
            onJoin: () {},
            onLeave: () {},
            onStart: () {},
            onCancel: () {},
            onAction: (_, __) {},
            onExpired: () {},
          ),
        ),
      ),
    );

    expect(
      find.text('Masa sahibi başka bir masaya katıldığı için oyun sona erdi.'),
      findsOneWidget,
    );
    expect(find.text('TABLE_OWNER_JOINED_ANOTHER_TABLE'), findsNothing);
  });

  testWidgets('countdown uses server offset and reports expiry once', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 8, 30, 18);
    var expiries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TableGroupGameCountdown(
          deadline: now.add(const Duration(seconds: 20)),
          serverTime: now,
          expiryToken: 'game:1:DICE',
          onExpired: () => expiries += 1,
          now: () => now,
        ),
      ),
    );
    expect(find.text('00:20'), findsOneWidget);

    now = now.add(const Duration(seconds: 21));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('00:00'), findsOneWidget);
    expect(expiries, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(expiries, 1);
  });
}

Map<String, dynamic> _player(
  String userId,
  String username, {
  String status = 'ACTIVE',
  bool hasActed = false,
}) {
  return <String, dynamic>{
    'userId': userId,
    'username': username,
    'status': status,
    'joinedAt': '2026-08-30T17:59:00Z',
    'hasActed': hasActed,
  };
}

Map<String, dynamic> _gameMessageJson({
  String gameId = 'game-1',
  String messageId = 'game-message-1',
  String sentAt = '2026-08-30T18:00:00Z',
  String serverTime = '2026-08-30T18:00:00Z',
  int revision = 1,
  String mode = 'DICE',
  String status = 'LOBBY',
  String phase = 'LOBBY',
  String? outcome,
  String? resultMessage,
  String? cancellationReason,
  List<Object?>? players,
  List<Object?>? revealedActions,
}) {
  return <String, dynamic>{
    'messageId': messageId,
    'tableGroupId': 'g-1',
    'senderId': 'owner',
    'content': resultMessage ?? 'Hesap Kimde oyunu',
    'messageType': 'GAME',
    'sentAt': sentAt,
    'deletedAt': null,
    'game': <String, dynamic>{
      'schemaVersion': 1,
      'gameId': gameId,
      'tableGroupId': 'g-1',
      'revision': revision,
      'topic': 'WHO_PAYS',
      'mode': mode,
      'status': status,
      'phase': phase,
      'createdBy': 'owner',
      'createdByUsername': 'ece',
      'round': 1,
      'joinDeadlineAt': '2026-08-30T18:03:00Z',
      'actionDeadlineAt': '2026-08-30T18:00:20Z',
      'serverTime': serverTime,
      'players': players ?? <Object?>[_player('owner', 'ece')],
      'revealedActions': revealedActions ?? <Object?>[],
      'selectedUserId': status == 'COMPLETED' ? 'owner' : null,
      'selectedUsername': status == 'COMPLETED' ? 'ece' : null,
      'outcome': outcome,
      'resultMessage': resultMessage,
      'cancellationReason': cancellationReason,
    },
  };
}

TableGroupMessage _gameMessage({
  String gameId = 'game-1',
  String messageId = 'game-message-1',
  String sentAt = '2026-08-30T18:00:00Z',
  String serverTime = '2026-08-30T18:00:00Z',
  int revision = 1,
  String mode = 'DICE',
  String status = 'LOBBY',
  String phase = 'LOBBY',
  String? outcome,
  String? resultMessage,
  String? cancellationReason,
  List<Object?>? players,
  List<Object?>? revealedActions,
}) {
  return TableGroupMessageModel.fromWireJson(
    _gameMessageJson(
      gameId: gameId,
      messageId: messageId,
      sentAt: sentAt,
      serverTime: serverTime,
      revision: revision,
      mode: mode,
      status: status,
      phase: phase,
      outcome: outcome,
      resultMessage: resultMessage,
      cancellationReason: cancellationReason,
      players: players,
      revealedActions: revealedActions,
    ),
  );
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient(this.response);

  Object? response;
  String? path;
  Object? body;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) async {
    this.path = path;
    return decoder == null ? response as T : decoder(response);
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) async {
    this.path = path;
    this.body = body;
    return decoder == null ? response as T : decoder(response);
  }

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();

  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => throw UnimplementedError();
}

class _GameRepositoryFake implements TableGroupGameRepository {
  _GameRepositoryFake({
    this.createResults = const <Result<TableGroupMessage>>[],
    this.actionResults = const <Result<TableGroupMessage>>[],
    this.activeCompleter,
    this.createCompleter,
    this.actionCompleter,
  });

  final List<Result<TableGroupMessage>> createResults;
  final List<Result<TableGroupMessage>> actionResults;
  final Completer<Result<TableGroupMessage?>>? activeCompleter;
  final Completer<Result<TableGroupMessage>>? createCompleter;
  final Completer<Result<TableGroupMessage>>? actionCompleter;
  final List<String> createRequestIds = <String>[];
  final List<String> actionRequestIds = <String>[];
  int _createIndex = 0;
  int _actionIndex = 0;

  static const _failure = Result<TableGroupMessage>.failure(
    AppError(code: 'test', message: 'failure'),
  );

  @override
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  }) =>
      activeCompleter?.future ??
      Future<Result<TableGroupMessage?>>.value(
        const Result<TableGroupMessage?>.success(null),
      );

  @override
  Future<Result<TableGroupMessage>> createGame({
    required String tableGroupId,
    required String requestId,
    required TableGroupGameMode mode,
  }) async {
    createRequestIds.add(requestId);
    final pending = createCompleter;
    if (pending != null) return pending.future;
    if (_createIndex >= createResults.length) return _failure;
    return createResults[_createIndex++];
  }

  @override
  Future<Result<TableGroupMessage>> submitAction({
    required String tableGroupId,
    required String gameId,
    required String requestId,
    required TableGroupGameAction action,
    String? targetUserId,
  }) {
    actionRequestIds.add(requestId);
    final pending = actionCompleter;
    if (pending != null) return pending.future;
    if (_actionIndex >= actionResults.length) {
      return Future<Result<TableGroupMessage>>.value(_failure);
    }
    return Future<Result<TableGroupMessage>>.value(
      actionResults[_actionIndex++],
    );
  }

  @override
  Future<Result<TableGroupMessage>> cancelGame({
    required String tableGroupId,
    required String gameId,
  }) async => _failure;

  @override
  Future<Result<TableGroupMessage>> getGame({
    required String tableGroupId,
    required String gameId,
  }) async => _failure;

  @override
  Future<Result<TableGroupMessage>> joinGame({
    required String tableGroupId,
    required String gameId,
  }) async => _failure;

  @override
  Future<Result<TableGroupMessage>> leaveGame({
    required String tableGroupId,
    required String gameId,
  }) async => _failure;

  @override
  Future<Result<TableGroupMessage>> startGame({
    required String tableGroupId,
    required String gameId,
  }) async => _failure;
}
