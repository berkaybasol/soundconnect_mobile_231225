import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/discovery_event.dart';
import '../domain/event_discovery_repository.dart';
import 'event_endpoints.dart';
import 'models/discovery_event_model.dart';

class EventDiscoveryRepositoryImpl implements EventDiscoveryRepository {
  final ApiClient _apiClient;

  EventDiscoveryRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<DiscoveryEvent>>> getTodayEvents() {
    return _fetchList(
      path: EventEndpoints.today,
      fallbackCode: 'event_today_unknown',
      fallbackMessage: 'Bugunku etkinlikler alinamadi',
    );
  }

  @override
  Future<Result<List<DiscoveryEvent>>> getEventsByCity(String cityId) {
    return _fetchList(
      path: EventEndpoints.byCity(cityId),
      fallbackCode: 'event_city_unknown',
      fallbackMessage: 'Sehire gore etkinlikler alinamadi',
    );
  }

  @override
  Future<Result<List<DiscoveryEvent>>> getEventsByDistrict(String districtId) {
    return _fetchList(
      path: EventEndpoints.byDistrict(districtId),
      fallbackCode: 'event_district_unknown',
      fallbackMessage: 'Ilceye gore etkinlikler alinamadi',
    );
  }

  @override
  Future<Result<List<DiscoveryEvent>>> getEventsByNeighborhood(
    String neighborhoodId,
  ) {
    return _fetchList(
      path: EventEndpoints.byNeighborhood(neighborhoodId),
      fallbackCode: 'event_neighborhood_unknown',
      fallbackMessage: 'Mahalleye gore etkinlikler alinamadi',
    );
  }

  @override
  Future<Result<List<DiscoveryEvent>>> getEventsByVenue(String venueId) {
    return _fetchList(
      path: EventEndpoints.byVenue(venueId),
      fallbackCode: 'event_venue_unknown',
      fallbackMessage: 'Mekana gore etkinlikler alinamadi',
    );
  }

  Future<Result<List<DiscoveryEvent>>> _fetchList({
    required String path,
    required String fallbackCode,
    required String fallbackMessage,
  }) async {
    try {
      final response = await _apiClient.get<List<DiscoveryEvent>>(
        path,
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(DiscoveryEventModel.fromJson)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        AppError(code: fallbackCode, message: fallbackMessage),
      );
    }
  }
}
