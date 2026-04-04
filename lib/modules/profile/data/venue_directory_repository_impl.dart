import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/profile_venue_models.dart';
import '../domain/venue_directory_repository.dart';

class VenueDirectoryRepositoryImpl implements VenueDirectoryRepository {
  final ApiClient _apiClient;

  VenueDirectoryRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<VenueOption>>> getAllVenues() async {
    try {
      final response = await _apiClient.get<List<VenueOption>>(
        '/api/v1/venues/get-all',
        decoder: (json) {
          final list = json as List<dynamic>? ?? const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(_venueOptionFromJson)
              .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_directory_unknown',
          message: 'Venue listesi alinamadi',
        ),
      );
    }
  }

  VenueOption _venueOptionFromJson(Map<String, dynamic> json) {
    return VenueOption(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      profilePictureUrl:
          json['profilePictureUrl']?.toString() ??
          json['profilePicture']?.toString() ??
          json['imageUrl']?.toString(),
      cityId: _extractId(json, 'cityId'),
      districtId: _extractId(json, 'districtId'),
      neighborhoodId: _extractId(json, 'neighborhoodId'),
      cityName: _extractName(json, 'cityName'),
      districtName: _extractName(json, 'districtName'),
      neighborhoodName: _extractName(json, 'neighborhoodName'),
    );
  }

  String? _extractId(Map<String, dynamic> item, String key) {
    final direct = item[key];
    if (direct != null && direct.toString().isNotEmpty) {
      return direct.toString();
    }
    final directUuid = item[key.replaceAll('Id', 'Uuid')];
    if (directUuid != null && directUuid.toString().isNotEmpty) {
      return directUuid.toString();
    }
    final nested = item[key.replaceAll('Id', '')];
    if (nested is Map<String, dynamic>) {
      final nestedId = nested['id'];
      if (nestedId != null && nestedId.toString().isNotEmpty) {
        return nestedId.toString();
      }
      final nestedUuid = nested['uuid'];
      if (nestedUuid != null && nestedUuid.toString().isNotEmpty) {
        return nestedUuid.toString();
      }
    }
    return null;
  }

  String? _extractName(Map<String, dynamic> item, String key) {
    final direct = item[key];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }
    final nested = item[key.replaceAll('Name', '')];
    if (nested is Map<String, dynamic>) {
      final nestedName = nested['name'];
      if (nestedName != null && nestedName.toString().trim().isNotEmpty) {
        return nestedName.toString().trim();
      }
    }
    return null;
  }
}
