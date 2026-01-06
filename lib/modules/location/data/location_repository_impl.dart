import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/location_repository.dart';
import '../domain/entities/city.dart';
import '../domain/entities/district.dart';
import '../domain/entities/neighborhood.dart';
import 'location_endpoints.dart';
import 'models/city_model.dart';
import 'models/district_model.dart';
import 'models/neighborhood_model.dart';

class LocationRepositoryImpl implements LocationRepository {
  final ApiClient _apiClient;

  LocationRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<City>>> getCities() async {
    try {
      final response = await _apiClient.get<List<City>>(
        LocationEndpoints.getAllCities,
        decoder: (json) {
          final list = (json as List<dynamic>? ?? [])
              .map((item) => CityModel.fromJson(item as Map<String, dynamic>))
              .map((model) => model.toEntity())
              .toList();
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'location_cities_unknown',
        message: 'Cities could not be loaded',
      ));
    }
  }

  @override
  Future<Result<List<District>>> getDistricts(String cityId) async {
    try {
      final response = await _apiClient.get<List<District>>(
        LocationEndpoints.getDistrictsByCity(cityId),
        decoder: (json) {
          final list = (json as List<dynamic>? ?? [])
              .map((item) => DistrictModel.fromJson(item as Map<String, dynamic>))
              .map((model) => model.toEntity())
              .toList();
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'location_districts_unknown',
        message: 'Districts could not be loaded',
      ));
    }
  }

  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(String districtId) async {
    try {
      final response = await _apiClient.get<List<Neighborhood>>(
        LocationEndpoints.getNeighborhoodsByDistrict(districtId),
        decoder: (json) {
          final list = (json as List<dynamic>? ?? [])
              .map(
                (item) => NeighborhoodModel.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .map((model) => model.toEntity())
              .toList();
          return list;
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(const AppError(
        code: 'location_neighborhoods_unknown',
        message: 'Neighborhoods could not be loaded',
      ));
    }
  }
}
