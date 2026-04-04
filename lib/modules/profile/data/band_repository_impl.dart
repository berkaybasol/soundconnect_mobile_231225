import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/band_repository.dart';
import '../domain/entities/band_profile.dart';
import '../domain/entities/band_summary.dart';
import 'band_endpoints.dart';
import 'models/band_create_request.dart';
import 'models/band_profile_model.dart';
import 'models/band_summary_model.dart';
import 'models/band_update_request.dart';

class BandRepositoryImpl implements BandRepository {
  final ApiClient _apiClient;

  BandRepositoryImpl(this._apiClient);

  @override
  Future<Result<List<BandSummary>>> getMyBands() async {
    try {
      final response = await _apiClient.get<List<BandSummary>>(
        BandEndpoints.myBands,
        decoder: (json) {
          final list = json is List ? json : const [];
          return list
              .whereType<Map<String, dynamic>>()
              .map(BandSummaryModel.fromJson)
              .toList();
        },
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_list_unknown',
          message: 'Bandler getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<BandProfile>> getBandById(String bandId) async {
    try {
      final response = await _apiClient.get<BandProfile>(
        BandEndpoints.byId(bandId),
        decoder: (json) =>
            BandProfileModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_profile_unknown',
          message: 'Band profili getirilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<BandSummary>> createBand({
    required String name,
    String? description,
  }) async {
    try {
      final response = await _apiClient.post<BandSummary>(
        BandEndpoints.create,
        body: BandCreateRequest(name: name, description: description).toJson(),
        decoder: (json) =>
            BandSummaryModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_create_unknown',
          message: 'Band olusturulamadi',
        ),
      );
    }
  }

  @override
  Future<Result<BandProfile>> updateBand({
    required String bandId,
    String? name,
    String? description,
    String? profilePicture,
    String? instagramUrl,
    String? youtubeUrl,
    String? soundCloudUrl,
    String? spotifyEmbedUrl,
    String? spotifyArtistId,
    List<String>? spotifyTrackIds,
  }) async {
    try {
      final response = await _apiClient.put<BandProfile>(
        BandEndpoints.byId(bandId),
        body: BandUpdateRequest(
          name: name,
          description: description,
          profilePicture: profilePicture,
          instagramUrl: instagramUrl,
          youtubeUrl: youtubeUrl,
          soundCloudUrl: soundCloudUrl,
          spotifyEmbedUrl: spotifyEmbedUrl,
          spotifyArtistId: spotifyArtistId,
          spotifyTrackIds: spotifyTrackIds,
        ).toJson(),
        decoder: (json) =>
            BandProfileModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_update_unknown',
          message: 'Band guncellenemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> inviteMember({
    required String bandId,
    required String invitedUserId,
    String? message,
  }) async {
    try {
      await _apiClient.post<Object?>(
        BandEndpoints.invite(bandId, invitedUserId, message: message),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_invite_unknown',
          message: 'Band daveti gonderilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> removeMember({
    required String bandId,
    required String userId,
  }) async {
    try {
      await _apiClient.delete<Object?>(
        BandEndpoints.removeMember(bandId, userId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_remove_member_unknown',
          message: 'Band uyesi cikarilamadi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> leaveBand({required String bandId}) async {
    try {
      await _apiClient.put<Object?>(
        BandEndpoints.leave(bandId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_leave_unknown',
          message: 'Bandden ayrilma islemi tamamlanamadi',
        ),
      );
    }
  }
}
