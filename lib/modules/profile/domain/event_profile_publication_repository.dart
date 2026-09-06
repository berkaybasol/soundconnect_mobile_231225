import '../../../core/error/result.dart';
import 'entities/event_performer_request.dart';
import 'entities/event_profile_publication.dart';

abstract class EventProfilePublicationRepository {
  Future<Result<EventProfilePublicationPage>> listMine({
    required EventPerformerTargetType targetType,
    required String targetId,
    EventProfilePublicationPeriod period = EventProfilePublicationPeriod.all,
    int page = 0,
    int size = 20,
  });

  /// Updates only this profile's publication choice. A stale version fails
  /// without retrying or altering another event/profile's choice.
  Future<Result<EventProfilePublication>> setVisible({
    required String eventId,
    required EventPerformerTargetType targetType,
    required String targetId,
    required bool visible,
    required int version,
  });
}
