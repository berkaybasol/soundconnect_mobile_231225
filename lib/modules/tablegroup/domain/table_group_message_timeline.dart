import 'entities/table_group_message.dart';

/// Produces the canonical chat timeline used by both REST pages and realtime
/// frames.
///
/// The backend pages newest messages first so that page zero opens at the
/// current conversation. The UI, however, renders oldest-to-newest. Keeping
/// that normalization in one place also protects the timeline from duplicate
/// REST/WS delivery of the same message.
List<TableGroupMessage> mergeTableGroupMessagesChronologically({
  Iterable<TableGroupMessage> existing = const <TableGroupMessage>[],
  required Iterable<TableGroupMessage> incoming,
}) {
  final byId = <String, TableGroupMessage>{};

  for (final message in existing) {
    final id = message.messageId.trim();
    if (id.isNotEmpty) byId[id] = message;
  }
  for (final message in incoming) {
    final id = message.messageId.trim();
    if (id.isEmpty) continue;
    final existingMessage = byId[id];
    byId[id] = existingMessage == null
        ? message
        : _preferLatestRevision(existingMessage, message);
  }

  final messages = byId.values.toList(growable: false)..sort(_compareMessages);
  return List<TableGroupMessage>.unmodifiable(messages);
}

/// Returns whether [candidate] is a newer revision of the same structured game
/// message than [baseline]. Text messages are immutable and therefore never
/// count as an in-place revision.
bool isNewerTableGroupGameMessage(
  TableGroupMessage candidate,
  TableGroupMessage baseline,
) {
  final candidateGame = candidate.game;
  final baselineGame = baseline.game;
  return candidate.messageId == baseline.messageId &&
      candidateGame != null &&
      baselineGame != null &&
      candidateGame.gameId == baselineGame.gameId &&
      candidateGame.revision > baselineGame.revision;
}

/// Returns whether [candidate] is a fresher snapshot of the same game card.
/// Equal revisions can legitimately be projected again with a newer server
/// clock; an older REST page must not overwrite a fresher realtime snapshot.
bool isFresherTableGroupGameMessage(
  TableGroupMessage candidate,
  TableGroupMessage baseline,
) {
  final candidateGame = candidate.game;
  final baselineGame = baseline.game;
  if (candidate.messageId != baseline.messageId ||
      candidateGame == null ||
      baselineGame == null ||
      candidateGame.gameId != baselineGame.gameId) {
    return false;
  }
  if (candidateGame.revision != baselineGame.revision) {
    return candidateGame.revision > baselineGame.revision;
  }
  final candidateServerTime = candidateGame.serverTime;
  final baselineServerTime = baselineGame.serverTime;
  if (candidateServerTime == null) return false;
  if (baselineServerTime == null) return true;
  return candidateServerTime.isAfter(baselineServerTime);
}

TableGroupMessage _preferLatestRevision(
  TableGroupMessage existing,
  TableGroupMessage incoming,
) {
  final existingGame = existing.game;
  final incomingGame = incoming.game;
  if (existingGame != null &&
      incomingGame != null &&
      existingGame.gameId == incomingGame.gameId) {
    return isFresherTableGroupGameMessage(incoming, existing)
        ? incoming
        : existing;
  }
  return incoming;
}

int _compareMessages(TableGroupMessage left, TableGroupMessage right) {
  final leftTime = left.sentAt;
  final rightTime = right.sentAt;
  if (leftTime != null && rightTime != null) {
    final timeComparison = leftTime.compareTo(rightTime);
    if (timeComparison != 0) return timeComparison;
  } else if (leftTime == null && rightTime != null) {
    return 1;
  } else if (leftTime != null && rightTime == null) {
    return -1;
  }

  // UUIDs are not temporal, but they provide a deterministic tie-breaker for
  // equal/missing timestamps and prevent visual reordering between rebuilds.
  return left.messageId.compareTo(right.messageId);
}
