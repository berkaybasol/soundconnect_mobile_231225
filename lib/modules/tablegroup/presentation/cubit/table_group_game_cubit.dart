import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/table_group_game.dart';
import '../../domain/entities/table_group_message.dart';
import '../../domain/table_group_game_repository.dart';
import '../../domain/table_group_message_timeline.dart';
import 'table_group_game_state.dart';

class TableGroupGameCubit extends Cubit<TableGroupGameState> {
  TableGroupGameCubit({
    required TableGroupGameRepository repository,
    required this.tableGroupId,
    String Function()? requestIdFactory,
  }) : _repository = repository,
       _requestIdFactory = requestIdFactory ?? const Uuid().v4,
       super(const TableGroupGameState.idle());

  final TableGroupGameRepository _repository;
  final String tableGroupId;
  final String Function() _requestIdFactory;

  Future<void>? _loadInFlight;
  Future<TableGroupMessage?>? _actionFuture;
  _RetryableGameCommand? _retryableCommand;
  final Set<String> _supersededGameIds = <String>{};
  int _generation = 0;

  Future<void> loadActive({bool exposeError = true}) {
    final inFlight = _loadInFlight;
    if (inFlight != null) return inFlight;
    final future = _loadActiveInternal(exposeError: exposeError);
    _loadInFlight = future;
    return future.whenComplete(() {
      if (identical(_loadInFlight, future)) _loadInFlight = null;
    });
  }

  Future<void> _loadActiveInternal({required bool exposeError}) async {
    final generation = _generation;
    final before = state.message;
    emit(
      state.copyWith(loading: true, error: exposeError ? null : state.error),
    );
    final result = await _repository.getActiveGame(tableGroupId: tableGroupId);
    if (isClosed || generation != _generation) return;
    if (!result.isSuccess) {
      emit(
        state.copyWith(
          loading: false,
          error: exposeError ? result.error : state.error,
        ),
      );
      return;
    }
    final incoming = result.data;
    if (incoming == null) {
      final unchangedWhileLoading = identical(state.message, before);
      emit(
        state.copyWith(
          message: unchangedWhileLoading ? null : state.message,
          loading: false,
          error: null,
        ),
      );
      return;
    }
    final mayUseAuthoritativeSwitch = !_movedToDifferentGame(
      before,
      state.message,
    );
    _acceptMessage(
      incoming,
      loading: false,
      authoritativeDifferentGame: mayUseAuthoritativeSwitch,
      allowHistoricalGameSwitch: mayUseAuthoritativeSwitch,
    );
  }

  Future<bool> refreshGame(String gameId) async {
    if (state.loading) return false;
    final generation = _generation;
    emit(state.copyWith(loading: true, error: null));
    final result = await _repository.getGame(
      tableGroupId: tableGroupId,
      gameId: gameId,
    );
    if (isClosed || generation != _generation) return false;
    if (!result.isSuccess || result.data == null) {
      emit(state.copyWith(loading: false, error: result.error));
      return false;
    }
    _acceptMessage(result.data!, loading: false);
    return true;
  }

  void acceptRealtimeMessage(TableGroupMessage message) {
    if (message.tableGroupId != tableGroupId ||
        message.messageType.trim().toUpperCase() != 'GAME' ||
        message.game == null) {
      return;
    }
    _acceptMessage(message);
  }

  void acceptHistoryMessage(TableGroupMessage message) {
    if (message.tableGroupId != tableGroupId ||
        message.messageType.trim().toUpperCase() != 'GAME' ||
        message.game == null) {
      return;
    }
    _acceptMessage(message, allowHistoricalGameSwitch: false);
  }

  Future<TableGroupMessage?> create(TableGroupGameMode mode) {
    final inFlight = _actionFuture;
    if (inFlight != null) return inFlight;
    final active = state.game;
    final signature =
        'create:${mode.name}:'
        '${active?.gameId ?? 'none'}:${active?.revision ?? -1}';
    final requestId = _requestIdFor(signature);
    return _runAction(
      () => _repository.createGame(
        tableGroupId: tableGroupId,
        requestId: requestId,
        mode: mode,
      ),
      retryableSignature: signature,
      authoritativeDifferentGame: true,
    );
  }

  Future<TableGroupMessage?> join(String gameId) {
    return _runAction(
      () => _repository.joinGame(tableGroupId: tableGroupId, gameId: gameId),
      clearRetryableCommand: true,
    );
  }

  Future<TableGroupMessage?> leave(String gameId) {
    return _runAction(
      () => _repository.leaveGame(tableGroupId: tableGroupId, gameId: gameId),
      clearRetryableCommand: true,
    );
  }

  Future<TableGroupMessage?> start(String gameId) {
    return _runAction(
      () => _repository.startGame(tableGroupId: tableGroupId, gameId: gameId),
      clearRetryableCommand: true,
    );
  }

  Future<TableGroupMessage?> cancel(String gameId) {
    return _runAction(
      () => _repository.cancelGame(tableGroupId: tableGroupId, gameId: gameId),
      clearRetryableCommand: true,
    );
  }

  Future<TableGroupMessage?> act({
    required String gameId,
    required TableGroupGameAction action,
    String? targetUserId,
  }) {
    final inFlight = _actionFuture;
    if (inFlight != null) return inFlight;
    final currentGame = state.game;
    final turnToken = currentGame?.gameId == gameId
        ? tableGroupGameTurnToken(currentGame!)
        : null;
    if (turnToken != null && state.committedTurnToken == turnToken) {
      return Future<TableGroupMessage?>.value();
    }
    final signature =
        'action:$gameId:${currentGame?.round ?? -1}:'
        '${currentGame?.phase.name ?? 'unknown'}:${action.wireValue}:'
        '${targetUserId?.trim() ?? ''}';
    final requestId = _requestIdFor(signature);
    return _runAction(
      () => _repository.submitAction(
        tableGroupId: tableGroupId,
        gameId: gameId,
        requestId: requestId,
        action: action,
        targetUserId: targetUserId,
      ),
      retryableSignature: signature,
      committedTurnTokenOnSuccess: turnToken,
    );
  }

  Future<TableGroupMessage?> _runAction(
    Future<Result<TableGroupMessage>> Function() operation, {
    String? retryableSignature,
    bool clearRetryableCommand = false,
    bool authoritativeDifferentGame = false,
    String? committedTurnTokenOnSuccess,
  }) {
    final inFlight = _actionFuture;
    if (inFlight != null) return inFlight;
    if (clearRetryableCommand) _retryableCommand = null;
    final generation = _generation;
    final messageAtStart = state.message;
    final future = _runActionInternal(
      operation,
      generation: generation,
      messageAtStart: messageAtStart,
      retryableSignature: retryableSignature,
      authoritativeDifferentGame: authoritativeDifferentGame,
      committedTurnTokenOnSuccess: committedTurnTokenOnSuccess,
    );
    _actionFuture = future;
    return future.whenComplete(() {
      if (identical(_actionFuture, future)) _actionFuture = null;
    });
  }

  Future<TableGroupMessage?> _runActionInternal(
    Future<Result<TableGroupMessage>> Function() operation, {
    required int generation,
    required TableGroupMessage? messageAtStart,
    required String? retryableSignature,
    required bool authoritativeDifferentGame,
    required String? committedTurnTokenOnSuccess,
  }) async {
    emit(state.copyWith(actionInFlight: true, error: null));
    final result = await operation();
    if (isClosed || generation != _generation) return null;
    if (!result.isSuccess || result.data == null) {
      emit(state.copyWith(actionInFlight: false, error: result.error));
      return null;
    }
    if (_retryableCommand?.signature == retryableSignature) {
      _retryableCommand = null;
    }
    if (committedTurnTokenOnSuccess != null) {
      emit(state.copyWith(committedTurnToken: committedTurnTokenOnSuccess));
    }
    final mayUseAuthoritativeSwitch =
        authoritativeDifferentGame &&
        !_movedToDifferentGame(messageAtStart, state.message);
    _acceptMessage(
      result.data!,
      actionInFlight: false,
      authoritativeDifferentGame: mayUseAuthoritativeSwitch,
      allowHistoricalGameSwitch:
          !authoritativeDifferentGame || mayUseAuthoritativeSwitch,
    );
    return result.data;
  }

  void _acceptMessage(
    TableGroupMessage incoming, {
    bool? loading,
    bool? actionInFlight,
    bool authoritativeDifferentGame = false,
    bool allowHistoricalGameSwitch = true,
  }) {
    final game = incoming.game;
    if (game == null ||
        incoming.tableGroupId != tableGroupId ||
        incoming.messageType.trim().toUpperCase() != 'GAME') {
      return;
    }
    final current = state.message;
    final currentGame = current?.game;
    final isDifferentGame =
        currentGame != null && currentGame.gameId != game.gameId;
    final wasSuperseded =
        currentGame?.gameId != game.gameId &&
        _supersededGameIds.contains(game.gameId);
    final shouldAccept =
        !wasSuperseded &&
        (currentGame == null ||
            (currentGame.gameId == game.gameId
                ? isFresherTableGroupGameMessage(incoming, current!)
                : (authoritativeDifferentGame ||
                      (allowHistoricalGameSwitch &&
                          _isLaterGameMessage(incoming, current!)))));
    if (shouldAccept && isDifferentGame) {
      _markSuperseded(currentGame.gameId);
    }
    final visibleGame = shouldAccept ? game : currentGame;
    final visibleTurnToken = visibleGame == null
        ? null
        : tableGroupGameTurnToken(visibleGame);
    final committedTurnToken = state.committedTurnToken == visibleTurnToken
        ? state.committedTurnToken
        : null;
    emit(
      state.copyWith(
        message: shouldAccept ? incoming : current,
        loading: loading ?? state.loading,
        actionInFlight: actionInFlight ?? state.actionInFlight,
        committedTurnToken: committedTurnToken,
        error: null,
      ),
    );
  }

  bool _movedToDifferentGame(
    TableGroupMessage? atStart,
    TableGroupMessage? current,
  ) {
    final currentGameId = current?.game?.gameId;
    return currentGameId != null && currentGameId != atStart?.game?.gameId;
  }

  bool _isLaterGameMessage(
    TableGroupMessage incoming,
    TableGroupMessage current,
  ) {
    final incomingGame = incoming.game!;
    final currentGame = current.game!;
    if (incomingGame.isTerminal != currentGame.isTerminal) {
      // There can be only one active game. Prefer that invariant over wall
      // clock timestamps, which are not monotonic across backend nodes.
      return !incomingGame.isTerminal;
    }
    if (!incomingGame.isTerminal) {
      // Realtime delivery order is authoritative for the one-active-game
      // invariant. The previous id is fenced below against delayed frames.
      return true;
    }
    final incomingTime = incoming.sentAt;
    final currentTime = current.sentAt;
    if (incomingTime != null && currentTime != null) {
      final comparison = incomingTime.compareTo(currentTime);
      if (comparison != 0) return comparison > 0;
    } else if (incomingTime != null) {
      return true;
    } else if (currentTime != null) {
      return false;
    }
    return incoming.messageId.compareTo(current.messageId) > 0;
  }

  void _markSuperseded(String gameId) {
    const maximumRememberedGames = 32;
    if (_supersededGameIds.length >= maximumRememberedGames &&
        !_supersededGameIds.contains(gameId)) {
      _supersededGameIds.remove(_supersededGameIds.first);
    }
    _supersededGameIds.add(gameId);
  }

  void clear() {
    if (isClosed) return;
    _generation += 1;
    _loadInFlight = null;
    _actionFuture = null;
    _retryableCommand = null;
    _supersededGameIds.clear();
    emit(const TableGroupGameState.idle());
  }

  String _requestIdFor(String signature) {
    final previous = _retryableCommand;
    if (previous != null && previous.signature == signature) {
      return previous.requestId;
    }
    final next = _RetryableGameCommand(
      signature: signature,
      requestId: _requestIdFactory(),
    );
    _retryableCommand = next;
    return next.requestId;
  }

  @override
  Future<void> close() {
    _generation += 1;
    _loadInFlight = null;
    _actionFuture = null;
    _retryableCommand = null;
    _supersededGameIds.clear();
    return super.close();
  }
}

class _RetryableGameCommand {
  const _RetryableGameCommand({
    required this.signature,
    required this.requestId,
  });

  final String signature;
  final String requestId;
}
