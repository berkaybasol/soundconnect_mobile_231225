import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/band_repository.dart';
import '../domain/band_member_title_policy.dart';
import '../domain/entities/band_member_summary.dart';
import '../domain/entities/band_pending_invitation.dart';
import '../domain/entities/band_received_invitation.dart';
import 'models/band_received_invitation_page_model.dart';
import '../domain/entities/band_profile.dart';
import '../domain/entities/band_summary.dart';
import 'band_endpoints.dart';
import 'models/band_create_request.dart';
import 'models/band_profile_model.dart';
import 'models/band_member_summary_model.dart';
import 'models/band_pending_invitation_page_model.dart';
import 'models/band_summary_model.dart';
import 'models/band_update_request.dart';

class BandRepositoryImpl implements BandRepository {
  final ApiClient _apiClient;

  BandRepositoryImpl(this._apiClient);

  @override
  Future<Result<BandReceivedInvitation>> getCurrentReceivedInvitation({
    required String bandId,
    required String expectedSessionKey,
  }) async {
    final id = bandId.trim();
    final key = expectedSessionKey.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) || key.isEmpty) {
      return const Result.failure(
        AppError(code: 'band_received_invalid', message: 'Davet açılamadı.'),
      );
    }
    try {
      final data = await _apiClient.request<BandReceivedInvitation>(
        ApiHttpMethod.get,
        BandEndpoints.currentReceivedInvitation(id),
        requestContext: ApiRequestContext(expectedSessionKey: key),
        decoder: BandReceivedInvitationPageModel.decodeInvitation,
      );
      if (data.bandId != id) {
        throw const FormatException('Wrong invitation target');
      }
      return Result.success(data);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'band_received_unknown',
          message: 'Güncel davet yüklenemedi.',
        ),
      );
    }
  }

  @override
  Future<Result<BandReceivedInvitationPage>> getReceivedInvitations({
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  }) async {
    final key = expectedSessionKey.trim();
    if (key.isEmpty ||
        page < 0 ||
        page > 10000 ||
        size < 1 ||
        size > 50 ||
        page * size > 100000) {
      return Result.failure(
        const AppError(
          code: 'band_received_invalid',
          message: 'Davet listesi açılamadı. Sayfayı yeniden aç.',
        ),
      );
    }
    try {
      final data = await _apiClient.request<BandReceivedInvitationPage>(
        ApiHttpMethod.get,
        BandEndpoints.receivedInvitations,
        query: {'page': page, 'size': size},
        requestContext: ApiRequestContext(expectedSessionKey: key),
        decoder: (json) => BandReceivedInvitationPageModel.decode(
          json,
          expectedPage: page,
          expectedSize: size,
        ),
      );
      return Result.success(data);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_received_unknown',
          message: 'Gelen davetler yüklenemedi. Tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<BandPendingInvitationPage>> getPendingInvitations({
    required String bandId,
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  }) async {
    final id = bandId.trim();
    final sessionKey = expectedSessionKey.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id) ||
        sessionKey.isEmpty ||
        page < 0 ||
        page > 10000 ||
        size < 1 ||
        size > 50 ||
        page * size > 100000) {
      return Result.failure(
        const AppError(
          code: 'band_pending_invalid',
          message: 'Davet listesi açılamadı. Sayfayı yeniden aç.',
        ),
      );
    }
    try {
      final response = await _apiClient.request<BandPendingInvitationPage>(
        ApiHttpMethod.get,
        BandEndpoints.pendingInvitations(id),
        query: {'page': page, 'size': size},
        requestContext: ApiRequestContext(expectedSessionKey: sessionKey),
        decoder: (json) => BandPendingInvitationPageModel.decode(
          json,
          expectedPage: page,
          expectedSize: size,
        ),
      );
      return Result.success(response);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_pending_unknown',
          message: 'Bekleyen davetler yüklenemedi. Tekrar dene.',
        ),
      );
    }
  }

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
  Future<Result<BandProfile>> getPublicBandById(String bandId) async {
    try {
      final response = await _apiClient.get<BandProfile>(
        BandEndpoints.publicById(bandId),
        decoder: (json) =>
            BandProfileModel.fromJson(json as Map<String, dynamic>),
      );
      return Result.success(response);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_public_profile_unknown',
          message: 'Public band profili getirilemedi',
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
          message: 'Band oluşturulamadı',
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
          message: 'Band güncellenemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> inviteMember({
    required String bandId,
    required String invitedUserId,
    String? message,
    String? expectedSessionKey,
  }) async {
    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.post,
        BandEndpoints.invite(bandId, invitedUserId, message: message),
        requestContext: expectedSessionKey == null
            ? null
            : ApiRequestContext(expectedSessionKey: expectedSessionKey),
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
  Future<Result<void>> acceptInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  }) async {
    if (invitationId == null ||
        !BandReceivedInvitationPageModel.isValidInvitationId(invitationId)) {
      return const Result.failure(
        AppError(
          code: 'band_invite_stale',
          message: 'Bu davet artık geçerli değil. Güncel daveti aç.',
        ),
      );
    }
    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.post,
        BandEndpoints.acceptInvite(bandId),
        query: {'invitationId': invitationId},
        requestContext: ApiRequestContext(
          expectedSessionKey: expectedSessionKey,
        ),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_accept_invite_unknown',
          message: 'Band daveti kabul edilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> rejectInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  }) async {
    if (invitationId == null ||
        !BandReceivedInvitationPageModel.isValidInvitationId(invitationId)) {
      return const Result.failure(
        AppError(
          code: 'band_invite_stale',
          message: 'Bu davet artık geçerli değil. Güncel daveti aç.',
        ),
      );
    }
    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.post,
        BandEndpoints.rejectInvite(bandId),
        query: {'invitationId': invitationId},
        requestContext: ApiRequestContext(
          expectedSessionKey: expectedSessionKey,
        ),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_reject_invite_unknown',
          message: 'Band daveti reddedilemedi',
        ),
      );
    }
  }

  @override
  Future<Result<void>> removeMember({
    required String bandId,
    required String userId,
    String? expectedSessionKey,
    int? expectedTitleVersion,
  }) async {
    if (expectedTitleVersion == null || expectedTitleVersion < 0) {
      return const Result.failure(
        AppError(
          code: '9221',
          message: 'Üyelik bilgileri değişti. Üyeleri yenileyip tekrar seç.',
        ),
      );
    }
    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.delete,
        BandEndpoints.removeMember(bandId, userId),
        query: {'expectedTitleVersion': expectedTitleVersion},
        requestContext: expectedSessionKey == null
            ? null
            : ApiRequestContext(expectedSessionKey: expectedSessionKey),
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
  Future<Result<void>> leaveBand({
    required String bandId,
    String? expectedSessionKey,
    int? expectedTitleVersion,
  }) async {
    if (expectedTitleVersion == null || expectedTitleVersion < 0) {
      return const Result.failure(
        AppError(
          code: '9221',
          message: 'Üyelik bilgileri değişti. Profili yenileyip tekrar dene.',
        ),
      );
    }
    try {
      await _apiClient.request<Object?>(
        ApiHttpMethod.patch,
        BandEndpoints.leave(bandId),
        query: {'expectedTitleVersion': expectedTitleVersion},
        requestContext: expectedSessionKey == null
            ? null
            : ApiRequestContext(expectedSessionKey: expectedSessionKey),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(
          code: 'band_leave_unknown',
          message: 'Gruptan ayrılamadın. Lütfen tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<BandMemberSummary>> updateMemberTitle({
    required String bandId,
    required String userId,
    required String? memberTitle,
    required int expectedTitleVersion,
    required String expectedSessionKey,
  }) async {
    final idPattern = RegExp(r'^[A-Za-z0-9_-]+$');
    final targetBandId = bandId.trim();
    final targetUserId = userId.trim();
    final sessionKey = expectedSessionKey.trim();
    final validation = BandMemberTitlePolicy.validationMessage(memberTitle);
    if (validation != null ||
        !idPattern.hasMatch(targetBandId) ||
        !idPattern.hasMatch(targetUserId) ||
        sessionKey.isEmpty ||
        expectedTitleVersion < 0 ||
        expectedTitleVersion == 0x7fffffffffffffff) {
      return Result.failure(
        AppError(
          code: 'band_member_title_invalid',
          message: validation ?? 'Üye bilgisi doğrulanamadı. Sayfayı yenile.',
        ),
      );
    }
    try {
      final response = await _apiClient.request<BandMemberSummary>(
        ApiHttpMethod.patch,
        BandEndpoints.memberTitle(targetBandId, targetUserId),
        body: <String, Object?>{
          'memberTitle': BandMemberTitlePolicy.normalize(memberTitle),
          'expectedTitleVersion': expectedTitleVersion,
        },
        requestContext: ApiRequestContext(expectedSessionKey: sessionKey),
        decoder: (json) {
          if (json is! Map<String, dynamic> ||
              !json.containsKey('memberTitle') ||
              json['titleVersion'] is! int) {
            throw const FormatException('Missing title update response');
          }
          return BandMemberSummaryModel.fromJson(json);
        },
      );
      if (response.userId.trim() != targetUserId ||
          response.status.trim().toUpperCase() != 'ACTIVE' ||
          response.role.trim().isEmpty ||
          BandMemberTitlePolicy.validationMessage(response.memberTitle) !=
              null ||
          response.titleVersion < expectedTitleVersion ||
          response.titleVersion > expectedTitleVersion + 1) {
        throw const FormatException('Unverified member title response');
      }
      return Result.success(response);
    } on ApiException catch (error) {
      return Result.failure(error.error);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'band_member_title_unverified',
          message:
              'Rol değişikliği doğrulanamadı. Üyeleri yenileyip tekrar dene.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteBand({required String bandId}) async {
    try {
      await _apiClient.delete<Object?>(
        BandEndpoints.delete(bandId),
        decoder: (_) => null,
      );
      return const Result.success(null);
    } on ApiException catch (e) {
      return Result.failure(e.error);
    } catch (_) {
      return Result.failure(
        const AppError(code: 'band_delete_unknown', message: 'Band silinemedi'),
      );
    }
  }
}
