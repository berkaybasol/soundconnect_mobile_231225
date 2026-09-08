import '../../../core/error/result.dart';
import 'entities/discovery_event_page.dart';

abstract class EventDiscoverySearchRepository {
  Future<Result<DiscoveryEventPage>> search({
    required DateTime date,
    required String cityId,
    String? districtId,
    String? neighborhoodId,
    int page = 0,
    int size = 20,
  });
}
