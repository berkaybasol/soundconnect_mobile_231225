import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/table_group_game.dart';
import '../domain/entities/table_group_message.dart';
import '../domain/table_group_game_repository.dart';
import 'models/table_group_message_model.dart';
import 'table_group_game_endpoints.dart';

class TableGroupGameRepositoryImpl implements TableGroupGameRepository {
  const TableGroupGameRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  }) async {
    try {
      final response = await _apiClient.get<TableGroupMessage?>(
        TableGroupGameEndpoints.active(tableGroupId),
        decoder: (json) => json == null
            ? null
            : _decodeMessage(json, expectedTableGroupId: tableGroupId),
      );
      return Result<TableGroupMessage?>.success(response);
    } on ApiException catch (error) {
      return Result<TableGroupMessage?>.failure(error.error);
    } catch (_) {
      return const Result<TableGroupMessage?>.failure(
        AppError(
          code: 'table_group_game_active_unknown',
          message: 'Aktif oyun getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<TableGroupMessage>> getGame({
    required String tableGroupId,
    required String gameId,
  }) {
    return _getGameMessage(
      TableGroupGameEndpoints.game(tableGroupId, gameId),
      tableGroupId: tableGroupId,
      expectedGameId: gameId,
      unknownCode: 'table_group_game_detail_unknown',
      unknownMessage: 'Oyun bilgisi getirilemedi',
    );
  }

  @override
  Future<Result<TableGroupMessage>> createGame({
    required String tableGroupId,
    required String requestId,
    required TableGroupGameMode mode,
  }) {
    if (mode == TableGroupGameMode.unknown) {
      return Future<Result<TableGroupMessage>>.value(
        const Result<TableGroupMessage>.failure(
          AppError(
            code: 'table_group_game_mode_invalid',
            message: 'Geçersiz oyun modu',
          ),
        ),
      );
    }
    return _postGameMessage(
      TableGroupGameEndpoints.games(tableGroupId),
      tableGroupId: tableGroupId,
      body: <String, dynamic>{
        'requestId': requestId,
        'mode': _modeWireValue(mode),
      },
      unknownCode: 'table_group_game_create_unknown',
      unknownMessage: 'Oyun baslatilamadi',
    );
  }

  @override
  Future<Result<TableGroupMessage>> joinGame({
    required String tableGroupId,
    required String gameId,
  }) {
    return _postGameMessage(
      TableGroupGameEndpoints.join(tableGroupId, gameId),
      tableGroupId: tableGroupId,
      expectedGameId: gameId,
      unknownCode: 'table_group_game_join_unknown',
      unknownMessage: 'Oyuna katilinamadi',
    );
  }

  @override
  Future<Result<TableGroupMessage>> leaveGame({
    required String tableGroupId,
    required String gameId,
  }) {
    return _postGameMessage(
      TableGroupGameEndpoints.leave(tableGroupId, gameId),
      tableGroupId: tableGroupId,
      expectedGameId: gameId,
      unknownCode: 'table_group_game_leave_unknown',
      unknownMessage: 'Oyundan ayrilinamadi',
    );
  }

  @override
  Future<Result<TableGroupMessage>> startGame({
    required String tableGroupId,
    required String gameId,
  }) {
    return _postGameMessage(
      TableGroupGameEndpoints.start(tableGroupId, gameId),
      tableGroupId: tableGroupId,
      expectedGameId: gameId,
      unknownCode: 'table_group_game_start_unknown',
      unknownMessage: 'Oyun baslatilamadi',
    );
  }

  @override
  Future<Result<TableGroupMessage>> cancelGame({
    required String tableGroupId,
    required String gameId,
  }) {
    return _postGameMessage(
      TableGroupGameEndpoints.cancel(tableGroupId, gameId),
      tableGroupId: tableGroupId,
      expectedGameId: gameId,
      unknownCode: 'table_group_game_cancel_unknown',
      unknownMessage: 'Oyun iptal edilemedi',
    );
  }

  @override
  Future<Result<TableGroupMessage>> submitAction({
    required String tableGroupId,
    required String gameId,
    required String requestId,
    required TableGroupGameAction action,
    String? targetUserId,
  }) {
    final normalizedTarget = targetUserId?.trim() ?? '';
    if (action == TableGroupGameAction.vote && normalizedTarget.isEmpty) {
      return Future<Result<TableGroupMessage>>.value(
        const Result<TableGroupMessage>.failure(
          AppError(
            code: 'table_group_game_vote_target_required',
            message: 'Oy verilecek oyuncu seçilmelidir',
          ),
        ),
      );
    }
    return _postGameMessage(
      TableGroupGameEndpoints.actions(tableGroupId, gameId),
      tableGroupId: tableGroupId,
      expectedGameId: gameId,
      body: <String, dynamic>{
        'requestId': requestId,
        'action': action.wireValue,
        if (action == TableGroupGameAction.vote)
          'targetUserId': normalizedTarget,
      },
      unknownCode: 'table_group_game_action_unknown',
      unknownMessage: 'Oyun hamlesi gonderilemedi',
    );
  }

  Future<Result<TableGroupMessage>> _getGameMessage(
    String path, {
    required String tableGroupId,
    String? expectedGameId,
    required String unknownCode,
    required String unknownMessage,
  }) async {
    try {
      final response = await _apiClient.get<TableGroupMessage>(
        path,
        decoder: (json) => _decodeMessage(
          json,
          expectedTableGroupId: tableGroupId,
          expectedGameId: expectedGameId,
        ),
      );
      return Result<TableGroupMessage>.success(response);
    } on ApiException catch (error) {
      return Result<TableGroupMessage>.failure(error.error);
    } catch (_) {
      return Result<TableGroupMessage>.failure(
        AppError(code: unknownCode, message: unknownMessage),
      );
    }
  }

  Future<Result<TableGroupMessage>> _postGameMessage(
    String path, {
    required String tableGroupId,
    String? expectedGameId,
    Object? body,
    required String unknownCode,
    required String unknownMessage,
  }) async {
    try {
      TableGroupMessage decode(Object? json) => _decodeMessage(
        json,
        expectedTableGroupId: tableGroupId,
        expectedGameId: expectedGameId,
      );

      final response = body == null
          ? await _apiClient.post<TableGroupMessage>(path, decoder: decode)
          : await _apiClient.post<TableGroupMessage>(
              path,
              body: body,
              decoder: decode,
            );
      return Result<TableGroupMessage>.success(response);
    } on ApiException catch (error) {
      return Result<TableGroupMessage>.failure(error.error);
    } catch (_) {
      return Result<TableGroupMessage>.failure(
        AppError(code: unknownCode, message: unknownMessage),
      );
    }
  }

  static TableGroupMessage _decodeMessage(
    Object? json, {
    required String expectedTableGroupId,
    String? expectedGameId,
  }) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid table-group game message');
    }
    final message = TableGroupMessageModel.fromWireJson(json);
    final game = message.game;
    if (message.messageType != 'GAME' || game == null) {
      throw const FormatException('Expected a table-group game message');
    }
    if (message.tableGroupId != expectedTableGroupId ||
        game.tableGroupId != expectedTableGroupId) {
      throw const FormatException('Table-group game group mismatch');
    }
    if (expectedGameId != null && game.gameId != expectedGameId) {
      throw const FormatException('Table-group game id mismatch');
    }
    return message;
  }

  static String _modeWireValue(TableGroupGameMode mode) {
    return switch (mode) {
      TableGroupGameMode.rockPaperScissors => 'ROCK_PAPER_SCISSORS',
      TableGroupGameMode.dice => 'DICE',
      TableGroupGameMode.vote => 'VOTE',
      TableGroupGameMode.unknown => 'UNKNOWN',
    };
  }
}
