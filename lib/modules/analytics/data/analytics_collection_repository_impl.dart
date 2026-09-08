import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/analytics_collection_repository.dart';
import '../domain/analytics_observation.dart';

class AnalyticsCollectionRepositoryImpl
    implements AnalyticsCollectionRepository {
  AnalyticsCollectionRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<String>>> collect({
    required String clientId,
    required List<AnalyticsObservation> observations,
    required String? expectedUserId,
  }) async {
    if (!isAnalyticsUuid(clientId) ||
        observations.isEmpty ||
        observations.length > 20 ||
        observations.any((value) => !value.isValid) ||
        observations.map((value) => value.id).toSet().length !=
            observations.length ||
        (expectedUserId != null && expectedUserId.trim().isEmpty)) {
      return const Result.failure(
        AppError(code: 'analytics_invalid', message: 'Geçersiz ölçüm bilgisi.'),
      );
    }
    try {
      final acknowledged = await _api.request<List<String>>(
        ApiHttpMethod.post,
        '/api/v1/analytics/observations',
        body: {
          'clientId': clientId,
          'observations': observations.map((value) => value.toJson()).toList(),
        },
        requestContext: ApiRequestContext(
          expectedSessionKey: expectedUserId,
          requireGuestSession: expectedUserId == null,
        ),
        decoder: (raw) {
          if (raw is! Map<String, dynamic> || raw['acknowledgedIds'] is! List) {
            throw const FormatException('Missing analytics acknowledgement');
          }
          final ids = raw['acknowledgedIds'] as List;
          final sentIds = observations.map((value) => value.id).toSet();
          if (ids.any((id) => id is! String || !sentIds.contains(id)) ||
              ids.toSet().length != ids.length) {
            throw const FormatException('Invalid analytics acknowledgement');
          }
          return List<String>.unmodifiable(ids.cast<String>());
        },
      );
      return Result.success(acknowledged);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      // Unknown outcomes are retried with the original observation IDs.
      return const Result.failure(
        AppError(
          code: 'analytics_unconfirmed',
          message: 'Ölçüm doğrulanamadı.',
        ),
      );
    }
  }
}
