class TableGroupGameEndpoints {
  static String games(String tableGroupId) =>
      '/api/v1/table-groups/$tableGroupId/chat/games';

  static String active(String tableGroupId) => '${games(tableGroupId)}/active';

  static String game(String tableGroupId, String gameId) =>
      '${games(tableGroupId)}/$gameId';

  static String join(String tableGroupId, String gameId) =>
      '${game(tableGroupId, gameId)}/join';

  static String leave(String tableGroupId, String gameId) =>
      '${game(tableGroupId, gameId)}/leave';

  static String start(String tableGroupId, String gameId) =>
      '${game(tableGroupId, gameId)}/start';

  static String cancel(String tableGroupId, String gameId) =>
      '${game(tableGroupId, gameId)}/cancel';

  static String actions(String tableGroupId, String gameId) =>
      '${game(tableGroupId, gameId)}/actions';
}
