import '../../../core/error/result.dart';
import 'entities/event_performer_request.dart';

abstract class EventPerformerRequestRepository {
  Future<Result<EventPerformerRequestPage>> listMine({
    EventPerformerRequestStatus status = EventPerformerRequestStatus.pending,
    int page = 0,
    int size = 20,
    EventPerformerTargetType? targetType,
    String? targetId,
  });

  Future<Result<void>> accept(String requestId, {bool showOnProfile = false});

  Future<Result<void>> reject(String requestId);

  /// Reopens only a rejected invitation that has not started. This is separate
  /// from accept so retries of the original decision cannot overturn a reject.
  Future<Result<void>> reconsider(
    String requestId, {
    required bool showOnProfile,
  });
}
