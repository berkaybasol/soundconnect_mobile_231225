import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/musician_feed_report_admin.dart';
import '../domain/musician_feed_report_admin_repository.dart';

class MusicianFeedReportAdminRepositoryImpl
    implements MusicianFeedReportAdminRepository {
  MusicianFeedReportAdminRepositoryImpl(this._api, this._sessions);
  final ApiClient _api;
  final AuthSessionManager _sessions;
  static const _path = '/api/v1/admin/musician-feed/reports';
  static const _restrictionsPath = '/api/v1/admin/musician-feed/restrictions';
  static const _invalid = AppError(
    code: 'feed_report_admin_invalid',
    message: 'Şikâyet bilgileri doğrulanamadı.',
  );
  static const _access = AppError(
    code: 'feed_report_admin_access_changed',
    message: 'Oturumun veya inceleme yetkin değişti. Bu sayfayı yeniden aç.',
  );
  static const _unknown = AppError(
    code: 'feed_report_admin_unavailable',
    message: 'İşlem tamamlanamadı. Lütfen tekrar dene.',
  );
  MusicianFeedReportAdminIdentity? get _identity =>
      musicianFeedReportAdminIdentity(_sessions.session);

  @override
  Future<Result<MusicianFeedReportAdminPage>> load({
    MusicianFeedReportStatus status = MusicianFeedReportStatus.fresh,
    String? itemType,
    int limit = 20,
    String? cursor,
  }) {
    if (limit < 1 ||
        limit > 50 ||
        (itemType != null &&
            !musicianFeedReportItemTypes.containsKey(itemType)) ||
        (cursor != null && (cursor.trim().isEmpty || cursor.length > 1024))) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.get,
      _path,
      query: {
        'status': status.apiValue,
        if (itemType != null) 'itemType': itemType,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
      decoder: MusicianFeedReportAdminPage.fromJson,
    );
  }

  @override
  Future<Result<MusicianFeedReportDetail>> detail(String reportId) {
    if (!isMusicianFeedReportId(reportId)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.get,
      '$_path/$reportId',
      decoder: (value) => _detailFor(reportId, value),
    );
  }

  @override
  Future<Result<MusicianFeedReportDetail>> review(
    String reportId, {
    required String clientRequestId,
    required int expectedVersion,
    required MusicianFeedReportDecision decision,
    required String resolutionNote,
  }) {
    if (!isMusicianFeedReportId(reportId) ||
        !isMusicianFeedReportId(clientRequestId) ||
        expectedVersion < 0 ||
        !isValidMusicianFeedResolutionNote(resolutionNote)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.post,
      '$_path/$reportId/review',
      body: {
        'clientRequestId': clientRequestId,
        'expectedVersion': expectedVersion,
        'decision': decision.apiValue,
        'resolutionNote': resolutionNote.trim(),
      },
      decoder: (value) => _detailFor(reportId, value),
    );
  }

  MusicianFeedReportDetail _detailFor(String reportId, Object? value) {
    final detail = MusicianFeedReportDetail.fromJson(value);
    if (detail.report.id != reportId) {
      throw const FormatException('Report response identity mismatch');
    }
    return detail;
  }

  @override
  Future<Result<MusicianFeedOrphanRestrictionsPage>> restrictions({
    int limit = 20,
    String? cursor,
  }) {
    if (limit < 1 ||
        limit > 50 ||
        (cursor != null && (cursor.trim().isEmpty || cursor.length > 1024))) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.get,
      _restrictionsPath,
      query: {'limit': limit, if (cursor != null) 'cursor': cursor},
      decoder: MusicianFeedOrphanRestrictionsPage.fromJson,
    );
  }

  @override
  Future<Result<MusicianFeedRestrictionRestored>> restoreRestriction(
    String reportId, {
    required String clientRequestId,
    required DateTime expectedUpdatedAt,
    required String resolutionNote,
  }) {
    if (!isMusicianFeedReportId(reportId) ||
        !isMusicianFeedReportId(clientRequestId) ||
        !expectedUpdatedAt.isUtc ||
        !isValidMusicianFeedResolutionNote(resolutionNote)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.post,
      '$_restrictionsPath/$reportId/restore',
      body: {
        'clientRequestId': clientRequestId,
        'expectedUpdatedAt': expectedUpdatedAt.toIso8601String(),
        'resolutionNote': resolutionNote.trim(),
      },
      decoder: (value) {
        final restored = MusicianFeedRestrictionRestored.fromJson(value);
        if (restored.reportId != reportId) {
          throw const FormatException('Restriction response identity mismatch');
        }
        return restored;
      },
    );
  }

  Future<Result<T>> _request<T>(
    ApiHttpMethod method,
    String path, {
    required T Function(Object?) decoder,
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final identity = _identity;
    if (identity == null) return const Result.failure(_access);
    // Remember transient revocation too: A -> B -> A must not accept A's old response.
    var accessChanged = false;
    void observe() {
      if (_identity != identity) accessChanged = true;
    }

    _sessions.addListener(observe);
    bool current() => !accessChanged && identity == _identity;
    try {
      final response = await _api.request<T>(
        method,
        path,
        query: query,
        body: body,
        requestContext: ApiRequestContext(
          expectedSessionKey: identity.userId,
          expectedToken: identity.token,
        ),
        decoder: decoder,
      );
      return current()
          ? Result.success(response)
          : const Result.failure(_access);
    } on ApiException catch (error) {
      return Result.failure(current() ? error.error : _access);
    } on FormatException {
      return Result.failure(current() ? _invalid : _access);
    } catch (_) {
      return Result.failure(current() ? _unknown : _access);
    } finally {
      _sessions.removeListener(observe);
    }
  }
}
