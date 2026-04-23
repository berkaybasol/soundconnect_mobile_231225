import '../../../core/error/result.dart';
import 'entities/discovery_event.dart';

abstract class EventDiscoveryRepository {
  Future<Result<List<DiscoveryEvent>>> getTodayEvents();
  Future<Result<List<DiscoveryEvent>>> getEventsByCity(String cityId);
  Future<Result<List<DiscoveryEvent>>> getEventsByDistrict(String districtId);
  Future<Result<List<DiscoveryEvent>>> getEventsByNeighborhood(
    String neighborhoodId,
  );
  Future<Result<List<DiscoveryEvent>>> getEventsByVenue(String venueId);
}
