part of 'promotion_repository_impl.dart';

mixin _PromotionAnnouncementOperations {
  ApiClient get _announcementApi;
  AuthSessionManager? get _announcementSessions;
  static const _adminPath = '/api/v1/admin/feed/announcements';
  static const _viewerPath = '/api/v1/announcements';
  Future<Result<AnnouncementStatistics>> announcementStatistics(
    String id, {
    String? from,
    String? to,
    String? profileType,
    String? source,
  }) {
    final first = from == null ? null : DateTime.tryParse(from);
    final last = to == null ? null : DateTime.tryParse(to);
    if (!isAnnouncementId(id) ||
        (profileType != null &&
            !announcementTargetProfiles.contains(profileType)) ||
        (source != null && source != 'FEED' && source != 'DIRECTORY') ||
        ((from == null) != (to == null)) ||
        (from != null &&
            (first == null ||
                last == null ||
                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(from) ||
                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(to!) ||
                last.isBefore(first) ||
                last.difference(first).inDays > 365))) {
      return Future.value(const Result.failure(_invalidAnnouncement));
    }
    return _announcementRequest(
      ApiHttpMethod.get,
      '$_adminPath/$id/statistics',
      admin: true,
      query: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (profileType != null) 'profileType': profileType,
        if (source != null) 'source': source,
      },
      decoder: (raw) {
        final result = AnnouncementStatistics.fromJson(raw);
        if (result.announcementId != id) {
          throw const FormatException('Statistics identity mismatch');
        }
        return result;
      },
    );
  }

  static const _invalidAnnouncement = AppError(
    code: 'announcement_invalid',
    message: 'Duyuru bilgileri doğrulanamadı.',
  );
  static const _announcementAccessChanged = AppError(
    code: 'announcement_access_changed',
    message: 'Oturumun veya yetkin değişti. Sayfayı yeniden aç.',
  );
  static const _announcementUnavailable = AppError(
    code: 'announcement_unavailable',
    message: 'Duyuru işlemi tamamlanamadı. Yeniden dene.',
  );

  Future<Result<AnnouncementPage>> announcements({
    String? cursor,
    int limit = 20,
    bool admin = false,
    AnnouncementStatus? status,
  }) {
    if (limit < 1 ||
        limit > 50 ||
        (!admin && status != null) ||
        (cursor != null &&
            (cursor.isEmpty ||
                cursor != cursor.trim() ||
                cursor.length > 4096))) {
      return Future.value(const Result.failure(_invalidAnnouncement));
    }
    return _announcementRequest(
      ApiHttpMethod.get,
      admin ? _adminPath : _viewerPath,
      admin: admin,
      query: {
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (status != null) 'status': status.wireValue,
      },
      decoder: (value) {
        final page = AnnouncementPage.fromJson(value);
        if (page.items.length > limit ||
            (page.hasMore && page.nextCursor == cursor)) {
          throw const FormatException('Announcement page did not advance');
        }
        return page;
      },
    );
  }

  Future<Result<Announcement>> announcement(String id, {bool admin = false}) {
    if (!isAnnouncementId(id)) {
      return Future.value(const Result.failure(_invalidAnnouncement));
    }
    return _announcementRequest(
      ApiHttpMethod.get,
      '${admin ? _adminPath : _viewerPath}/$id',
      admin: admin,
      decoder: (value) => _announcementFor(id, value),
    );
  }

  Future<Result<Announcement>> createAnnouncement(AnnouncementWrite input) {
    if (!input.isValid) {
      return Future.value(const Result.failure(_invalidAnnouncement));
    }
    return _announcementRequest(
      ApiHttpMethod.post,
      _adminPath,
      admin: true,
      body: input.toJson(),
      decoder: Announcement.fromJson,
    );
  }

  Future<Result<Announcement>> updateAnnouncement(
    String id,
    AnnouncementWrite input, {
    required int expectedVersion,
  }) {
    if (!isAnnouncementId(id) || expectedVersion < 0 || !input.isValid) {
      return Future.value(const Result.failure(_invalidAnnouncement));
    }
    return _announcementRequest(
      ApiHttpMethod.put,
      '$_adminPath/$id',
      admin: true,
      body: input.toJson(expectedVersion: expectedVersion),
      decoder: (value) => _announcementFor(id, value),
    );
  }

  Future<Result<Announcement>> publishAnnouncement(
    String id, {
    required int expectedVersion,
    DateTime? startsAt,
    DateTime? endsAt,
  }) {
    if (!isAnnouncementId(id) ||
        expectedVersion < 0 ||
        (startsAt != null && endsAt != null && !endsAt.isAfter(startsAt))) {
      return Future.value(const Result.failure(_invalidAnnouncement));
    }
    return _announcementRequest(
      ApiHttpMethod.post,
      '$_adminPath/$id/publish',
      admin: true,
      body: {
        'expectedVersion': expectedVersion,
        if (startsAt != null) 'startsAt': startsAt.toUtc().toIso8601String(),
        'endsAt': endsAt?.toUtc().toIso8601String(),
      },
      decoder: (value) => _announcementFor(id, value),
    );
  }

  Future<Result<Announcement>> endAnnouncement(
    String id, {
    required int expectedVersion,
  }) => _announcementTransition(id, 'end', expectedVersion);
  Future<Result<Announcement>> archiveAnnouncement(
    String id, {
    required int expectedVersion,
  }) => _announcementTransition(id, 'archive', expectedVersion);
  Future<Result<Announcement>> _announcementTransition(
    String id,
    String action,
    int version,
  ) {
    if (!isAnnouncementId(id) || version < 0) {
      return Future.value(const Result.failure(_invalidAnnouncement));
    }
    return _announcementRequest(
      ApiHttpMethod.post,
      '$_adminPath/$id/$action',
      admin: true,
      body: {'expectedVersion': version},
      decoder: (value) => _announcementFor(id, value),
    );
  }

  Future<Result<void>> deleteAnnouncement(
    String id, {
    required int expectedVersion,
  }) {
    if (!isAnnouncementId(id) || expectedVersion < 0) {
      return Future.value(const Result.failure(_invalidAnnouncement));
    }
    return _announcementRequest<void>(
      ApiHttpMethod.delete,
      '$_adminPath/$id',
      admin: true,
      query: {'version': expectedVersion},
      decoder: (_) {},
    );
  }

  Announcement _announcementFor(String id, Object? value) {
    final item = Announcement.fromJson(value);
    if (item.id != id) {
      throw const FormatException('Announcement response identity changed');
    }
    return item;
  }

  Future<Result<T>> _announcementRequest<T>(
    ApiHttpMethod method,
    String path, {
    required T Function(Object?) decoder,
    bool admin = false,
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final sessions = _announcementSessions;
    if (sessions == null) {
      return const Result.failure(_announcementAccessChanged);
    }
    final identity = announcementSessionIdentity(
      sessions.session,
      admin: admin,
    );
    if (identity == null) {
      return const Result.failure(_announcementAccessChanged);
    }
    var revoked = false;
    void observe() {
      if (announcementSessionIdentity(sessions.session, admin: admin) !=
          identity) {
        revoked = true;
      }
    }

    sessions.addListener(observe);
    bool current() =>
        !revoked &&
        identity == announcementSessionIdentity(sessions.session, admin: admin);
    try {
      final response = await _announcementApi.request<T>(
        method,
        path,
        query: query,
        body: body,
        decoder: decoder,
        requestContext: ApiRequestContext(
          expectedSessionKey: identity.userId,
          expectedToken: identity.token,
        ),
      );
      return current()
          ? Result.success(response)
          : const Result.failure(_announcementAccessChanged);
    } on ApiException catch (error) {
      return Result.failure(
        current() ? error.error : _announcementAccessChanged,
      );
    } on FormatException {
      return Result.failure(
        current() ? _invalidAnnouncement : _announcementAccessChanged,
      );
    } catch (_) {
      return Result.failure(
        current() ? _announcementUnavailable : _announcementAccessChanged,
      );
    } finally {
      sessions.removeListener(observe);
    }
  }
}
