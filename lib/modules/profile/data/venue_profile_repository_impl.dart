import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/venue_owner_profile.dart';
import '../domain/entities/venue_profile_summary.dart';
import '../domain/entities/venue_public_profile.dart';
import '../domain/venue_profile_repository.dart';
import 'models/venue_owner_profile_model.dart';
import 'models/venue_profile_summary_model.dart';
import 'models/venue_profile_save_request.dart';
import 'models/venue_public_profile_model.dart';
import 'venue_profile_endpoints.dart';

class VenueProfileRepositoryImpl implements VenueProfileRepository {
  final ApiClient _apiClient;
  final String? Function()? sessionKeyProvider;

  VenueProfileRepositoryImpl(this._apiClient, {this.sessionKeyProvider});

  String? get _session => sessionKeyProvider?.call()?.trim();
  bool _isCurrent(String? expected) =>
      sessionKeyProvider == null ||
      (expected?.isNotEmpty == true && expected == _session);
  static const _sessionError = AppError(
    code: 'venue_profile_session_changed',
    message: 'Oturum değişti. Mekân profilini yeniden aç.',
  );

  @override
  Future<Result<List<VenueProfileSummary>>> getMyVenueProfiles() =>
      _myProfiles(_session);

  Future<Result<List<VenueProfileSummary>>> _myProfiles(String? session) async {
    if (!_isCurrent(session)) return const Result.failure(_sessionError);
    try {
      final response = await _apiClient.request<List<VenueProfileSummary>>(
        ApiHttpMethod.get,
        VenueProfileEndpoints.myProfiles,
        requestContext: sessionKeyProvider == null
            ? null
            : ApiRequestContext(expectedSessionKey: session),
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(VenueProfileSummaryModel.fromJson)
              .toList();
        },
      );
      if (!_isCurrent(session)) return const Result.failure(_sessionError);
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_profile_list_unknown',
          message: 'Venue profilleri alinamadi',
        ),
      );
    }
  }

  @override
  Future<Result<VenueOwnerProfile>> getMyVenueProfileDetail({
    String? venueId,
  }) async {
    final session = _session;
    if (!_isCurrent(session)) return const Result.failure(_sessionError);
    try {
      final resolvedVenueId = await _resolveVenueId(venueId, session);
      if (!_isCurrent(session)) return const Result.failure(_sessionError);
      if (resolvedVenueId == null || resolvedVenueId.isEmpty) {
        return Result.failure(
          const AppError(
            code: 'venue_profile_missing',
            message: 'Kullaniciya ait venue bulunamadi',
          ),
        );
      }
      final response = await _apiClient.request<VenueOwnerProfile>(
        ApiHttpMethod.get,
        VenueProfileEndpoints.myDetail(resolvedVenueId),
        requestContext: sessionKeyProvider == null
            ? null
            : ApiRequestContext(expectedSessionKey: session),
        decoder: (json) =>
            VenueOwnerProfileModel.fromJson(json as Map<String, dynamic>),
      );
      if (!_isCurrent(session)) return const Result.failure(_sessionError);
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_owner_profile_unknown',
          message: 'Venue owner profili alinamadi',
        ),
      );
    }
  }

  @override
  Future<Result<VenueOwnerProfile>> updateMyVenueProfileDetail(
    VenueProfileSaveRequest request, {
    String? venueId,
  }) async {
    final session = _session;
    if (!_isCurrent(session)) return const Result.failure(_sessionError);
    try {
      final resolvedVenueId = await _resolveVenueId(venueId, session);
      if (!_isCurrent(session)) return const Result.failure(_sessionError);
      if (resolvedVenueId == null || resolvedVenueId.isEmpty) {
        return Result.failure(
          const AppError(
            code: 'venue_profile_missing',
            message: 'Kullaniciya ait venue bulunamadi',
          ),
        );
      }
      final response = await _apiClient.request<VenueOwnerProfile>(
        ApiHttpMethod.put,
        VenueProfileEndpoints.myDetail(resolvedVenueId),
        requestContext: sessionKeyProvider == null
            ? null
            : ApiRequestContext(expectedSessionKey: session),
        body: request.toJson(),
        decoder: (json) =>
            VenueOwnerProfileModel.fromJson(json as Map<String, dynamic>),
      );
      if (!_isCurrent(session)) return const Result.failure(_sessionError);
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_owner_profile_update_unknown',
          message: 'Venue owner profili guncellenemedi',
        ),
      );
    }
  }

  @override
  Future<Result<VenuePublicProfile>> getPublicVenueProfile({
    String? venueId,
  }) async {
    try {
      final resolvedVenueId = await _resolveVenueId(venueId, _session);
      if (resolvedVenueId == null || resolvedVenueId.isEmpty) {
        return Result.failure(
          const AppError(
            code: 'venue_public_profile_missing',
            message: 'Goruntulenecek venue bulunamadi',
          ),
        );
      }
      final response = await _apiClient.get<VenuePublicProfile>(
        VenueProfileEndpoints.publicDetail(resolvedVenueId),
        decoder: (json) =>
            VenuePublicProfileModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'venue_public_profile_unknown',
          message: 'Venue public profili alinamadi',
        ),
      );
    }
  }

  Future<String?> _resolveVenueId(String? venueId, String? session) async {
    if (venueId?.trim().isNotEmpty == true) return venueId!.trim();
    final profiles = await _myProfiles(session);
    if (!profiles.isSuccess) {
      throw ApiException(profiles.error ?? _sessionError);
    }
    if (profiles.data == null || profiles.data!.isEmpty) {
      return null;
    }
    return profiles.data!.first.venueId;
  }
}
