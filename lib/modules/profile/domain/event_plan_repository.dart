import '../../../core/error/result.dart';
import 'entities/event_plan.dart';
import 'entities/event_performer_request.dart';
import 'entities/venue_event_item.dart';

abstract class EventPlanRepository {
  Future<Result<VenueEventDraft>> copySource(String eventId, String venueId);
  Future<Result<EventPlanPreview>> preview(
    EventPlanDefinition definition, {
    String? planId,
    int? expectedVersion,
  });
  Future<Result<EventPlan>> create(
    String clientRequestId,
    EventPlanDefinition definition,
  );
  Future<Result<EventPlanPage<EventPlan>>> listOwner(
    String venueId, {
    int page = 0,
  });
  Future<Result<EventPlan>> getOwner(String planId);
  Future<Result<EventPlan>> update(
    EventPlan plan,
    EventPlanDefinition definition,
  );
  Future<Result<EventPlan>> stop(EventPlan plan, {required bool cancelFuture});
  Future<Result<EventPlanPage<EventPlanOccurrence>>> occurrences(
    String planId, {
    int page = 0,
  });
  Future<Result<EventPlan>> editOccurrence(
    EventPlan plan,
    EventPlanOccurrence occurrence, {
    required DateTime eventDate,
    required EventPlanTemplate template,
  });
  Future<Result<EventPlan>> skipOccurrence(
    EventPlan plan,
    EventPlanOccurrence occurrence,
  );
  Future<Result<EventPlanPage<EventPlan>>> listPerformer(
    EventPerformerTargetType type,
    String targetId, {
    int page = 0,
  });
  Future<Result<EventPlan>> getPerformer(String planId);
  Future<Result<EventPlan>> decide(
    EventPlan plan,
    String decision, {
    bool? showOnProfile,
  });
}
