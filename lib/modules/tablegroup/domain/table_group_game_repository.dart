import '../../../core/error/result.dart';
import 'entities/table_group_game.dart';
import 'entities/table_group_message.dart';

abstract class TableGroupGameRepository {
  Future<Result<TableGroupMessage?>> getActiveGame({
    required String tableGroupId,
  });

  Future<Result<TableGroupMessage>> getGame({
    required String tableGroupId,
    required String gameId,
  });

  Future<Result<TableGroupMessage>> createGame({
    required String tableGroupId,
    required String requestId,
    required TableGroupGameMode mode,
  });

  Future<Result<TableGroupMessage>> joinGame({
    required String tableGroupId,
    required String gameId,
  });

  Future<Result<TableGroupMessage>> leaveGame({
    required String tableGroupId,
    required String gameId,
  });

  Future<Result<TableGroupMessage>> startGame({
    required String tableGroupId,
    required String gameId,
  });

  Future<Result<TableGroupMessage>> cancelGame({
    required String tableGroupId,
    required String gameId,
  });

  Future<Result<TableGroupMessage>> submitAction({
    required String tableGroupId,
    required String gameId,
    required String requestId,
    required TableGroupGameAction action,
    String? targetUserId,
  });
}
