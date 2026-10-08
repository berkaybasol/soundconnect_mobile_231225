import '../../../core/error/app_error.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/profile_search_result.dart';
import '../domain/profile_search_repository.dart';

class ProfileSearchRepositoryImpl implements ProfileSearchRepository {
  final ApiClient _apiClient;
  final AuthSessionManager? _sessions;

  ProfileSearchRepositoryImpl(this._apiClient, {AuthSessionManager? sessions})
    : _sessions = sessions;

  @override
  Future<Result<List<ProfileSearchResult>>> searchProfiles(
    String query, {
    Set<ProfileSearchResultType>? types,
  }) async {
    try {
      final session = _sessions?.session;
      final listener =
          session?.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) == true;
      final normalizedQuery = query.trim();
      final requestedTypes = types?.isNotEmpty == true
          ? types!
          : ProfileSearchResultType.values.toSet();
      final allowedTypes = listener
          ? requestedTypes.difference(const {
              ProfileSearchResultType.studio,
              ProfileSearchResultType.unknown,
            })
          : types ?? const <ProfileSearchResultType>{};
      if (listener && allowedTypes.isEmpty) {
        return const Result.success(<ProfileSearchResult>[]);
      }
      final apiTypes =
          allowedTypes.map(_apiType).whereType<String>().toList(growable: false)
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
      if (_sessions != null && !identical(_sessions.session, session)) {
        return const Result.failure(
          AppError(
            code: 'profile_search_session_changed',
            message: 'Hesabın değişti. Aramayı yeniden dene.',
          ),
        );
      }
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
