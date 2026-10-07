part of 'notification_cubit.dart';

// The inbox owns the session and projection revisions. Keep its bounded,
// shared count flight together without introducing another owner or timer.
extension _NotificationCountReconciliation on NotificationCubit {
  Future<void> _reconcileConfirmedCount(
    int generation,
    int sessionRevision, {
    bool newMutation = true,
  }) {
    if (!_isCurrentSession(generation, sessionRevision)) {
      return Future<void>.value();
    }
    _countReconciliationNeeded = true;
    if (newMutation) _confirmedCountMutationRevision += 1;
    final inFlight = _countReconciliationInFlight;
    if (inFlight != null) return inFlight;
    final cancellation = Completer<void>();
    _countReconciliationCancellation = cancellation;
    final operation = _runCountReconciliation(
      generation,
      sessionRevision,
      cancellation,
    );
    _countReconciliationInFlight = operation;
    return operation.whenComplete(() {
      if (identical(_countReconciliationInFlight, operation)) {
        _countReconciliationInFlight = null;
        _countReconciliationCancellation = null;
      }
    });
  }

  Future<void> _runCountReconciliation(
    int generation,
    int sessionRevision,
    Completer<void> cancellation,
  ) async {
    // One shared flight. A newly confirmed mutation requires a snapshot taken
    // after its ACK; coalesce all such ACKs before the next request. In addition,
    // permit one contention retry for unversioned arrivals/other projections.
    // N additional confirmed mutations cost at most N+2 requests; an arrival
    // storm alone costs two. No timer polling or domain retry. Error/timeout
    // leaves the debt for a later mutation or existing badge/resume/refresh.
    var contentionRetryAvailable = true;
    while (_isCurrentSession(generation, sessionRevision)) {
      final mutationRevision = _confirmedCountMutationRevision;
      final serverRevision = _serverCountRevision;
      final badgeRevision = _badgeRevision;
      final realtimeRevision = _realtimeRevision;
      final timeout = Completer<Result<int>?>();
      final timer = Timer(
        _countReconciliationTimeout,
        () => timeout.complete(null),
      );
      Result<int>? result;
      try {
        result = await Future.any<Result<int>?>([
          _repository.getUnreadCount(),
          timeout.future,
          cancellation.future.then((_) => null),
        ]);
      } catch (_) {
        // A failed read-only projection does not undo the successful ACK or
        // leak an unobserved error through the synchronous DM callback.
        return;
      } finally {
        timer.cancel();
      }
      if (!_isCurrentSession(generation, sessionRevision) ||
          result == null ||
          !result.isSuccess ||
          result.data == null) {
        return;
      }
      if (_confirmedCountMutationRevision != mutationRevision) continue;
      // A newer local mutation/arrival may fall after this count's snapshot.
      // Read it again; never repeat DELETE or discard the loaded inbox rows.
      if (_badgeRevision != badgeRevision ||
          _realtimeRevision != realtimeRevision ||
          _serverCountRevision != serverRevision) {
        if (contentionRetryAvailable) {
          contentionRetryAvailable = false;
          continue;
        }
        return;
      }
      _acceptReconciledCount(result.data!);
      return;
    }
  }

  void _cancelCountReconciliation() {
    final cancellation = _countReconciliationCancellation;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
    _countReconciliationInFlight = null;
    _countReconciliationCancellation = null;
    _countReconciliationNeeded = false;
  }
}
