import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/venue_suggestion_repository.dart';

class VenueSuggestionRepositoryImpl implements VenueSuggestionRepository {
  VenueSuggestionRepositoryImpl(this._api);
  final ApiClient _api;

  @override
  Future<Result<void>> submit({
    required String requestId,
    required String venueName,
    required String cityId,
    required String districtId,
    required VenueSuggestionLiveMusic liveMusic,
  }) async {
    final name = venueName.trim();
    if (name.runes.length < 2 ||
        name.runes.length > 100 ||
        cityId.trim().isEmpty ||
        districtId.trim().isEmpty ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
        ).hasMatch(requestId)) {
      return const Result.failure(
        AppError(
          code: 'venue_suggestion_invalid',
          message: 'Öneri bilgilerini kontrol edip yeniden dene.',
        ),
      );
    }
    try {
      await _api.post<bool>(
        '/api/v1/venue-suggestions',
        body: {
          'requestId': requestId,
          'venueName': name,
          'cityId': cityId.trim(),
          'districtId': districtId.trim(),
          'liveMusic': liveMusic.name.toUpperCase(),
        },
        decoder: (raw) {
          if (raw is! Map<String, dynamic> || raw['accepted'] != true) {
            throw const FormatException(
              'Missing venue suggestion acknowledgement',
            );
          }
          return true;
        },
      );
      return const Result.success(null);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'venue_suggestion_unconfirmed',
          message:
              'Gönderim doğrulanamadı. Aynı bilgilerle yeniden deneyebilirsin.',
        ),
      );
    }
  }
}
