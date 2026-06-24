import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/profile_search_result.dart';
import '../domain/profile_search_repository.dart';

class ProfileSearchRepositoryImpl implements ProfileSearchRepository {
  final ApiClient _apiClient;

  ProfileSearchRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<ProfileSearchResult>>> searchProfiles(String query) async {
    try {
      final response = await _apiClient.get<List<ProfileSearchResult>>(
        '/api/v1/public/search/profiles',
        query: {'q': query, 'limit': 20},
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(ProfileSearchResult.fromJson)
              .where((item) =>
                  item.targetId.isNotEmpty &&
                  item.type != ProfileSearchResultType.unknown)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'profile_search_unknown',
          message: 'Arama şu anda yapılamıyor.',
        ),
      );
    }
  }
}
