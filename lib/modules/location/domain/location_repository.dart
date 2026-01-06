import '../../../core/error/result.dart';
import 'entities/city.dart';
import 'entities/district.dart';
import 'entities/neighborhood.dart';

abstract class LocationRepository {
  Future<Result<List<City>>> getCities();
  Future<Result<List<District>>> getDistricts(String cityId);
  Future<Result<List<Neighborhood>>> getNeighborhoods(String districtId);
}
