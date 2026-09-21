import '../../../core/error/result.dart';
import 'entities/venue_event_detail.dart';
import 'entities/venue_event_item.dart';
import 'entities/venue_event_management.dart';

abstract class VenueEventRepository {
  Future<Result<VenueEventManagementSnapshot>> loadManagement(String venueId);
  Future<Result<VenueEventHistoryPage>> loadHistory(
    String venueId, {
    required DateTime asOf,
    String? cursor,
  });
  Future<Result<List<VenueOwnerEventItem>>> listByVenue(String venueId);
  Future<Result<List<VenueOwnerEventItem>>> listPublicByVenue(String venueId);
  Future<Result<void>> create({
    required String venueId,
    required VenueEventDraft draft,
  });
  Future<Result<void>> delete(String eventId);
  Future<Result<VenueEventDetail>> getDetail(String eventId);
}
