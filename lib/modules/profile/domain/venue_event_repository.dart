import '../../../core/error/result.dart';
import '../presentation/screens/venue_event_support.dart';
import 'entities/venue_event_detail.dart';

abstract class VenueEventRepository {
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String venueId);
  Future<Result<void>> create({
    required String venueId,
    required VenueEventDraft draft,
  });
  Future<Result<void>> delete(String eventId);
  Future<Result<VenueEventDetail>> getDetail(String eventId);
}
