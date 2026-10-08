part of 'table_group_game_test.dart';

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
  String? createdByVisibilityMode,
  String? selectedUserVisibilityMode,
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
      createdByVisibilityMode: createdByVisibilityMode,
      selectedUserVisibilityMode: selectedUserVisibilityMode,
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
