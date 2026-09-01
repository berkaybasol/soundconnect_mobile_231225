import '../../../../core/error/app_error.dart';
import '../../../../core/state/copy_with.dart';
import '../../domain/entities/table_group_game.dart';
import '../../domain/entities/table_group_message.dart';

class TableGroupGameState {
  const TableGroupGameState({
    required this.message,
    required this.loading,
    required this.actionInFlight,
    required this.committedTurnToken,
    required this.error,
  });

  const TableGroupGameState.idle()
    : message = null,
      loading = false,
      actionInFlight = false,
      committedTurnToken = null,
      error = null;

  final TableGroupMessage? message;
  final bool loading;
  final bool actionInFlight;
  final String? committedTurnToken;
  final AppError? error;

  TableGroupGame? get game => message?.game;

  bool isActionCommittedFor(TableGroupGame game) =>
      committedTurnToken == tableGroupGameTurnToken(game);

  TableGroupGameState copyWith({
    Object? message = copyWithUnset,
    bool? loading,
    bool? actionInFlight,
    Object? committedTurnToken = copyWithUnset,
    Object? error = copyWithUnset,
  }) {
    return TableGroupGameState(
      message: identical(message, copyWithUnset)
          ? this.message
          : message as TableGroupMessage?,
      loading: loading ?? this.loading,
      actionInFlight: actionInFlight ?? this.actionInFlight,
      committedTurnToken: identical(committedTurnToken, copyWithUnset)
          ? this.committedTurnToken
          : committedTurnToken as String?,
      error: identical(error, copyWithUnset) ? this.error : error as AppError?,
    );
  }
}

String tableGroupGameTurnToken(TableGroupGame game) =>
    '${game.gameId}:${game.round}:${game.phase.name}';
