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

  VenueProfileRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<VenueProfileSummary>>> getMyVenueProfiles() async {
    try {
      final response = await _apiClient.get<List<VenueProfileSummary>>(
        VenueProfileEndpoints.myProfiles,
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(VenueProfileSummaryModel.fromJson)
              .toList();
        },
      );
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
    try {
      final resolvedVenueId = await _resolveVenueId(venueId);
      if (resolvedVenueId == null || resolvedVenueId.isEmpty) {
        return Result.failure(
          const AppError(
            code: 'venue_profile_missing',
            message: 'Kullaniciya ait venue bulunamadi',
          ),
        );
      }
      final response = await _apiClient.get<VenueOwnerProfile>(
        VenueProfileEndpoints.myDetail(resolvedVenueId),
        decoder: (json) =>
            VenueOwnerProfileModel.fromJson(json as Map<String, dynamic>),
      );
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
    try {
      final resolvedVenueId = await _resolveVenueId(venueId);
      if (resolvedVenueId == null || resolvedVenueId.isEmpty) {
        return Result.failure(
          const AppError(
            code: 'venue_profile_missing',
            message: 'Kullaniciya ait venue bulunamadi',
          ),
        );
      }
      final response = await _apiClient.put<VenueOwnerProfile>(
        VenueProfileEndpoints.myDetail(resolvedVenueId),
        body: request.toJson(),
        decoder: (json) =>
            VenueOwnerProfileModel.fromJson(json as Map<String, dynamic>),
      );
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
      final resolvedVenueId = await _resolveVenueId(venueId);
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

  Future<String?> _resolveVenueId(String? venueId) async {
    if (venueId != null && venueId.isNotEmpty) return venueId;
    final profiles = await getMyVenueProfiles();
    if (!profiles.isSuccess || profiles.data == null || profiles.data!.isEmpty) {
      return null;
    }
    return profiles.data!.first.venueId;
  }
}
