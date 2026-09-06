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
  Future<Result<List<ProfileSearchResult>>> searchProfiles(
    String query, {
    Set<ProfileSearchResultType>? types,
  }) async {
    try {
      final normalizedQuery = query.trim();
      final allowedTypes = types ?? const <ProfileSearchResultType>{};
      final apiTypes =
          (types ?? const <ProfileSearchResultType>{})
              .map(_apiType)
              .whereType<String>()
              .toList(growable: false)
            ..sort();
      final response = await _apiClient.get<List<ProfileSearchResult>>(
        '/api/v1/public/search/profiles',
        query: {
          'q': normalizedQuery,
          'limit': 20,
          if (apiTypes.isNotEmpty) 'types': apiTypes.join(','),
        },
        decoder: (json) {
          if (json is! List<dynamic>) {
            throw const FormatException('Expected a profile search list.');
          }
          final results = <ProfileSearchResult>[];
          final seen = <(ProfileSearchResultType, String)>{};
          for (final raw in json) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Invalid profile search item.');
            }
            final item = ProfileSearchResult.fromJson(raw);
            if (item.targetId.isEmpty ||
                item.title.isEmpty ||
                item.type == ProfileSearchResultType.unknown) {
              throw const FormatException(
                'Profile search identity is missing.',
              );
            }
            if (allowedTypes.isNotEmpty && !allowedTypes.contains(item.type)) {
              continue;
            }
            if (seen.add((item.type, item.targetId))) {
              results.add(item);
            }
          }
          return List<ProfileSearchResult>.unmodifiable(results);
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } on FormatException {
      return const Result.failure(
        AppError(
          code: 'profile_search_malformed_response',
          message: 'Profil araması geçersiz bir yanıt döndürdü.',
        ),
      );
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'profile_search_unknown',
          message: 'Arama şu anda yapılamıyor.',
        ),
      );
    }
  }

  String? _apiType(ProfileSearchResultType type) {
    return switch (type) {
      ProfileSearchResultType.musician => 'MUSICIAN',
      ProfileSearchResultType.listener => 'LISTENER',
      ProfileSearchResultType.band => 'BAND',
      ProfileSearchResultType.studio => 'STUDIO',
      ProfileSearchResultType.venue => 'VENUE',
      ProfileSearchResultType.unknown => null,
    };
  }
}
