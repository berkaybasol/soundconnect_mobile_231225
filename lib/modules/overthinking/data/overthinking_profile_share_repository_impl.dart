import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../profile/data/profile_share_api.dart';
import '../domain/overthinking_profile_share_repository.dart';
import 'models/overthinking_post_model.dart';

class OverthinkingProfileShareRepositoryImpl
    implements OverthinkingProfileShareRepository {
  OverthinkingProfileShareRepositoryImpl(
    ApiClient api, {
    required AuthSessionManager sessions,
  }) : _transport = ProfileShareApi(
         api,
         sessions: sessions,
         sessionError: _sessionError,
         unavailableError: _unavailable,
         definitiveRejectionCodes: const {'9401', '9413', '9414', '9415'},
       );

  final ProfileShareApi _transport;

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
  ValueListenable<int> get changes => _transport.changes;

  void dispose() => _transport.dispose();

  @override
  Future<Result<OverthinkingProfileShareState>> getState({
    required String postId,
    required AuthSession expectedSession,
  }) => _transport.request(
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
  }) => _transport.request(
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
  }) => _transport.request<void>(
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
  }) => _transport.request(
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
            likeCount: _count(row['likeCount']),
            commentCount: _count(row['commentCount']),
            likedByMe: _bool(row['likedByMe']),
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

  static int _count(Object? raw) {
    if (raw is! int || raw < 0 || raw > 9007199254740991) {
      throw const FormatException('Invalid engagement count');
    }
    return raw;
  }

  static DateTime _instant(Object? raw) {
    if (raw is! String) throw const FormatException('Invalid publication time');
    return DateTime.parse(raw);
  }
}
