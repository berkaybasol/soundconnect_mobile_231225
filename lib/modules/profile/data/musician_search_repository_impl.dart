import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/musician_search_option.dart';
import '../domain/musician_search_repository.dart';

class MusicianSearchRepositoryImpl implements MusicianSearchRepository {
  final ApiClient _apiClient;

  MusicianSearchRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<MusicianSearchOption>>> search(String query) async {
    try {
      final response = await _apiClient.get<List<MusicianSearchOption>>(
        '/api/v1/public/musician-profiles/search',
        query: {'q': query},
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(MusicianSearchOption.fromJson)
              .where((item) => item.profileId.isNotEmpty)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'musician_search_unknown',
          message: 'Muzisyen aramasi yapilamadi',
        ),
      );
    }
  }
}
