import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/overthinking_profile_share_repository.dart';
import 'models/overthinking_post_model.dart';

class OverthinkingProfileShareRepositoryImpl
    implements OverthinkingProfileShareRepository {
  OverthinkingProfileShareRepositoryImpl(
    this._api, {
    required AuthSessionManager sessions,
  }) : _sessions = sessions {
    _sessions.addListener(_sessionChanged);
  }

  final ApiClient _api;
  final AuthSessionManager _sessions;
  final ValueNotifier<int> _changes = ValueNotifier(0);
  int _sessionEpoch = 0;
  bool _disposed = false;
  bool _pendingReconciliation = false;

  static const _base = '/api/v1/overthinking';
  static const _sessionError = AppError(
    code: 'overthinking_profile_share_session_changed',
    message: 'Oturum değişti. Sayfayı yeniden aç.',
  );
  static const _unavailable = AppError(
    code: 'overthinking_profile_share_unavailable',
    message: 'Profil paylaşımı şu anda yüklenemiyor. Yeniden dene.',
  );

  @override
  ValueListenable<int> get changes => _changes;

  void _sessionChanged() {
    ++_sessionEpoch;
    _pendingReconciliation = false;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sessions.removeListener(_sessionChanged);
    _changes.dispose();
  }

  bool _current(AuthSession expected, int epoch) =>
      !_disposed &&
      epoch == _sessionEpoch &&
      identical(_sessions.session, expected);

  Future<Result<T>> _request<T>({
    required AuthSession expected,
    required ApiHttpMethod method,
    required String Function() path,
    required T Function(Object?) decoder,
    Object? Function()? body,
    Map<String, dynamic>? Function()? query,
    bool listenerOnly = true,
    bool invalidates = false,
    bool reconciles = false,
  }) async {
    final epoch = _sessionEpoch;
    if (!_current(expected, epoch) ||
        !expected.isAuthenticated ||
        !expected.isActive ||
        expected.userId?.trim().isNotEmpty != true ||
        (listenerOnly && !canShareOverthinkingOnProfile(expected))) {
      return const Result.failure(_sessionError);
    }
    var dispatched = false;
    try {
      final requestPath = path();
      final requestBody = body?.call();
      final requestQuery = query?.call();
      dispatched = true;
      final value = await _api.request<T>(
        method,
        requestPath,
        body: requestBody,
        query: requestQuery,
        decoder: decoder,
        requestContext: ApiRequestContext(
          expectedSessionKey: expected.userId,
          expectedToken: expected.token,
        ),
      );
      if (!_current(expected, epoch)) {
        return const Result.failure(_sessionError);
      }
      if (invalidates || (reconciles && _pendingReconciliation)) {
        if (reconciles) _pendingReconciliation = false;
        _changes.value++;
      }
      return _current(expected, epoch)
          ? Result.success(value)
          : const Result.failure(_sessionError);
    } on ApiException catch (error) {
      if (invalidates &&
          dispatched &&
          !_definitiveRejection(error.error.code)) {
        _invalidateUncertain(expected, epoch);
      }
      return Result.failure(
        _current(expected, epoch) ? error.error : _sessionError,
      );
    } catch (_) {
      if (invalidates && dispatched) _invalidateUncertain(expected, epoch);
      return Result.failure(
        _current(expected, epoch) ? _unavailable : _sessionError,
      );
    }
  }

  void _invalidateUncertain(AuthSession expected, int epoch) {
    if (!_current(expected, epoch)) return;
    // An HTTP failure or malformed success can follow a committed write. This
    // asks observers to read again; it never invents a publication locally.
    _pendingReconciliation = true;
    _changes.value++;
  }

  static bool _definitiveRejection(String code) {
    final status = int.tryParse(code);
    return (status != null && status >= 400 && status < 500 && status != 408) ||
        const {
          '1101',
          '1102',
          '1301',
          '1308',
          '9401',
          '9413',
          '9414',
          '9415',
          'api_session_fence',
        }.contains(code);
  }

  @override
  Future<Result<OverthinkingProfileShareState>> getState({
    required String postId,
    required AuthSession expectedSession,
  }) => _request(
    expected: expectedSession,
    method: ApiHttpMethod.get,
    path: () => '$_base/${_id(postId)}/profile-share',
    reconciles: true,
    decoder: (raw) => _state(raw, postId),
  );

  @override
  Future<Result<OverthinkingProfileShareState>> publish({
    required String postId,
    String? note,
    required AuthSession expectedSession,
  }) => _request(
    expected: expectedSession,
    method: ApiHttpMethod.put,
    path: () => '$_base/${_id(postId)}/profile-share',
    body: () => {'note': _note(note)},
    invalidates: true,
    decoder: (raw) {
      final state = _state(raw, postId);
      if (!state.publishedOnProfile || state.note != _note(note)) {
        throw const FormatException('Profile share was not confirmed');
      }
      return state;
    },
  );

  @override
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  }) => _request<void>(
    expected: expectedSession,
    method: ApiHttpMethod.delete,
    path: () => '$_base/profile-shares/${_id(shareId)}',
    invalidates: true,
    decoder: (raw) {
      if (raw != null) throw const FormatException('Invalid deletion result');
    },
  );

  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) => _request(
    expected: expectedSession,
    method: ApiHttpMethod.get,
    path: () =>
        '/api/v1/public/listener-profiles/${_id(profileId)}/overthinking-posts',
    listenerOnly: false,
    query: () {
      if (page < 0 || page > 1000 || size < 1 || size > 50) {
        throw const FormatException('Invalid page');
      }
      return {'page': page, 'size': size};
    },
    decoder: (raw) => _page(raw, page),
  );

  static OverthinkingProfileShareState _state(Object? raw, String expectedId) {
    final json = _map(raw);
    final postId = _id(json['postId']);
    final published = _bool(json['publishedOnProfile']);
    final shareId = json['shareId'] == null ? null : _id(json['shareId']);
    final publishedAt = json['publishedAt'] == null
        ? null
        : _instant(json['publishedAt']);
    final note = _note(json['note']);
    if (postId != expectedId ||
        (published && (shareId == null || publishedAt == null)) ||
        (!published &&
            (shareId != null || note != null || publishedAt != null))) {
      throw const FormatException('Inconsistent profile publication');
    }
    return OverthinkingProfileShareState(
      postId: postId,
      shareId: shareId,
      publishedOnProfile: published,
      note: note,
      publishedAt: publishedAt,
      canPublish: _bool(json['canPublish']),
    );
  }

  static Page<OverthinkingProfileShare> _page(Object? raw, int requestedPage) {
    final json = _map(raw);
    final content = json['content'];
    if (content is! List || json['number'] != requestedPage) {
      throw const FormatException('Invalid publication page');
    }
    final last = _bool(json['last']);
    final ids = <String>{};
    final items = content
        .map((raw) {
          final row = _map(raw);
          final shareId = _id(row['shareId']);
          if (!ids.add(shareId)) {
            throw const FormatException('Duplicate publication');
          }
          final source = _map(row['post']);
          _id(source['id']);
          return OverthinkingProfileShare(
            shareId: shareId,
            note: _note(row['note']),
            publishedAt: _instant(row['publishedAt']),
            post: OverthinkingPostModel.fromJson(source),
          );
        })
        .toList(growable: false);
    return Page(
      items: items,
      hasNext: !last,
      nextCursor: last ? null : '${requestedPage + 1}',
    );
  }

  static Map<String, dynamic> _map(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid object');
    }
    return raw;
  }

  static String _id(Object? raw) {
    if (raw is! String ||
        raw.trim().isEmpty ||
        raw != raw.trim() ||
        !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(raw)) {
      throw const FormatException('Invalid identity');
    }
    return raw;
  }

  static String? _note(Object? raw) {
    if (raw == null) return null;
    if (raw is! String) throw const FormatException('Invalid publication note');
    final note = raw.trim();
    if (note.runes.length > 500 ||
        note.runes.any(
          (point) =>
              (point < 32 && point != 9 && point != 10) ||
              (point >= 127 && point <= 159) ||
              (point >= 0xd800 && point <= 0xdfff),
        )) {
      throw const FormatException('Invalid publication note');
    }
    return note.isEmpty ? null : note;
  }

  static bool _bool(Object? raw) {
    if (raw is! bool) throw const FormatException('Invalid boolean');
    return raw;
  }

  static DateTime _instant(Object? raw) {
    if (raw is! String) throw const FormatException('Invalid publication time');
    return DateTime.parse(raw);
  }
}
