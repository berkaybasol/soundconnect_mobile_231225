import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/notification_campaign.dart';

class NotificationCampaignRepository {
  NotificationCampaignRepository(this._api, this._sessions);
  final ApiClient _api;
  final AuthSessionManager _sessions;
  static const path = '/api/v1/admin/notifications/campaigns';
  static const _access = AppError(
    code: 'campaign_access_changed',
    message: 'Oturumun veya yönetim yetkin değişti. Sayfayı yeniden aç.',
  );
  static const _invalid = AppError(
    code: 'campaign_invalid',
    message: 'Bildirim bilgileri doğrulanamadı.',
  );

  Future<Result<CampaignPage>> load({int page = 0}) {
    if (page < 0) return Future.value(const Result.failure(_invalid));
    return _request(
      ApiHttpMethod.get,
      path,
      query: {'page': page, 'size': 20},
      decode: (raw) {
        final result = CampaignPage.fromJson(raw);
        if (result.page != page) {
          throw const FormatException('Campaign page mismatch');
        }
        return result;
      },
    );
  }

  Future<Result<NotificationCampaign>> get(String id) {
    if (!isCampaignId(id)) return Future.value(const Result.failure(_invalid));
    return _request(
      ApiHttpMethod.get,
      '$path/$id',
      decode: (raw) => _identity(raw, id),
    );
  }

  Future<Result<NotificationCampaign>> save(
    CampaignInput input, {
    NotificationCampaign? existing,
    String? requestId,
  }) {
    if (input.validationError != null ||
        (existing != null && !existing.editable) ||
        (existing == null && (requestId == null || !isCampaignId(requestId)))) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      existing == null ? ApiHttpMethod.post : ApiHttpMethod.put,
      existing == null ? path : '$path/${existing.id}',
      body: {
        ...input.toJson(expectedVersion: existing?.version),
        if (existing == null) 'requestId': requestId,
      },
      decode: (raw) => existing == null
          ? NotificationCampaign.fromJson(raw)
          : _identity(raw, existing.id),
    );
  }

  Future<Result<NotificationCampaign>> transition(
    NotificationCampaign campaign,
    String action,
  ) {
    final allowed = switch (action) {
      'schedule' => campaign.status == 'DRAFT',
      'pause' => campaign.status == 'SCHEDULED',
      'resume' => campaign.status == 'PAUSED',
      'cancel' => const {
        'DRAFT',
        'SCHEDULED',
        'PAUSED',
      }.contains(campaign.status),
      _ => false,
    };
    if (!allowed || !isCampaignId(campaign.id)) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.post,
      '$path/${campaign.id}/$action',
      body: {'expectedVersion': campaign.version},
      decode: (raw) => _identity(raw, campaign.id),
    );
  }

  Future<Result<List<CampaignLookup>>> search(
    String query, {
    String? targetKind,
  }) {
    final q = query.trim();
    if (q.length < 2 ||
        q.length > 80 ||
        (targetKind != null &&
            !const {'PROFILE', 'EVENT', 'CONTENT'}.contains(targetKind))) {
      return Future.value(const Result.failure(_invalid));
    }
    return _request(
      ApiHttpMethod.get,
      '$path/${targetKind == null ? 'users' : 'targets'}',
      query: {'q': q, if (targetKind != null) 'kind': targetKind},
      decode: (raw) {
        if (raw is! List || raw.length > 20) {
          throw const FormatException('Invalid lookup results');
        }
        final values = raw.map(CampaignLookup.fromJson).toList();
        if (values.map((v) => v.id).toSet().length != values.length) {
          throw const FormatException('Duplicate lookup identity');
        }
        return List.unmodifiable(values);
      },
    );
  }

  NotificationCampaign _identity(Object? raw, String id) {
    final value = NotificationCampaign.fromJson(raw);
    if (value.id != id) {
      throw const FormatException('Campaign identity mismatch');
    }
    return value;
  }

  Future<Result<T>> _request<T>(
    ApiHttpMethod method,
    String url, {
    Map<String, dynamic>? query,
    Object? body,
    required T Function(Object?) decode,
  }) async {
    final session = _sessions.session;
    if (!canManageNotificationCampaigns(session)) {
      return const Result.failure(_access);
    }
    var changed = false;
    void observe() {
      if (!identical(session, _sessions.session)) changed = true;
    }

    _sessions.addListener(observe);
    bool current() =>
        !changed &&
        identical(session, _sessions.session) &&
        canManageNotificationCampaigns(_sessions.session);
    try {
      final value = await _api.request<T>(
        method,
        url,
        query: query,
        body: body,
        decoder: decode,
        requestContext: ApiRequestContext(
          expectedSessionKey: session.userId,
          expectedToken: session.token,
        ),
      );
      return current() ? Result.success(value) : const Result.failure(_access);
    } on ApiException catch (error) {
      return Result.failure(current() ? error.error : _access);
    } on FormatException {
      return Result.failure(current() ? _invalid : _access);
    } catch (_) {
      return Result.failure(
        current()
            ? const AppError(
                code: 'campaign_unavailable',
                message:
                    'İşlem doğrulanamadı. Kayıtlı durumu yenileyip tekrar dene.',
              )
            : _access,
      );
    } finally {
      _sessions.removeListener(observe);
    }
  }
}
