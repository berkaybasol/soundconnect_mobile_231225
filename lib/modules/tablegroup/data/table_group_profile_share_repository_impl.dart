import 'package:flutter/foundation.dart';

import '../../../core/auth/auth_session.dart';
import '../../../core/auth/auth_session_manager.dart';
import '../../../core/error/app_error.dart';
import '../../../core/error/result.dart';
import '../../../core/network/api_client.dart';
import '../../profile/data/profile_share_api.dart';
import '../domain/table_group_profile_share_repository.dart';
import 'models/table_group_wire_date.dart';

class TableGroupProfileShareRepositoryImpl
    implements TableGroupProfileShareRepository {
  TableGroupProfileShareRepositoryImpl(
    ApiClient api, {
    required AuthSessionManager sessions,
  }) : _transport = ProfileShareApi(
         api,
         sessions: sessions,
         sessionError: _sessionError,
         unavailableError: _unavailable,
         definitiveRejectionCodes: const {'9129', '9130', '9131', '9133'},
       );

  final ProfileShareApi _transport;

  static const _base = '/api/v1/table-groups';
  static const _sessionError = AppError(
    code: 'table_group_profile_share_session_changed',
    message: 'Oturum değişti. Sayfayı yeniden aç.',
  );
  static const _unavailable = AppError(
    code: 'table_group_profile_share_unavailable',
    message: 'Profil paylaşımı şu anda yüklenemiyor. Yeniden dene.',
  );

  @override
  ValueListenable<int> get changes => _transport.changes;

  void dispose() => _transport.dispose();

  @override
  Future<Result<TableGroupProfileShareState>> getState({
    required String tableGroupId,
    required AuthSession expectedSession,
  }) => _transport.request(
    expected: expectedSession,
    method: ApiHttpMethod.get,
    path: () => '$_base/${_id(tableGroupId)}/profile-share',
    reconciles: true,
    decoder: (raw) => _state(raw, tableGroupId),
  );

  @override
  Future<Result<TableGroupProfileShareState>> publish({
    required String tableGroupId,
    String? note,
    required AuthSession expectedSession,
  }) => _transport.request(
    expected: expectedSession,
    method: ApiHttpMethod.put,
    path: () => '$_base/${_id(tableGroupId)}/profile-share',
    body: () => {'note': _note(note)},
    invalidates: true,
    decoder: (raw) {
      final state = _state(raw, tableGroupId);
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
  Future<Result<Page<TableGroupProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) => _transport.request(
    expected: expectedSession,
    method: ApiHttpMethod.get,
    path: () =>
        '/api/v1/public/listener-profiles/${_id(profileId)}/table-group-posts',
    listenerOnly: false,
    query: () {
      if (page < 0 || page > 1000 || size < 1 || size > 50) {
        throw const FormatException('Invalid page');
      }
      return {'page': page, 'size': size};
    },
    decoder: (raw) => _page(raw, page),
  );

  @override
  Future<Result<List<TableGroupProfileShare>>> lookupProfile({
    required String profileId,
    required AuthSession expectedSession,
    required Set<String> shareIds,
  }) => _transport.request(
    expected: expectedSession,
    method: ApiHttpMethod.get,
    path: () =>
        '/api/v1/public/listener-profiles/${_id(profileId)}/table-group-posts/lookup',
    listenerOnly: false,
    query: () {
      if (shareIds.isEmpty || shareIds.length > 50) {
        throw const FormatException('Invalid publication lookup');
      }
      return {'shareIds': shareIds.map(_id).join(',')};
    },
    decoder: (raw) {
      if (raw is! List) {
        throw const FormatException('Invalid publication lookup result');
      }
      final seen = <String>{};
      return raw
          .map((row) {
            final publication = _publication(row);
            if (!shareIds.contains(publication.shareId) ||
                !seen.add(publication.shareId)) {
              throw const FormatException(
                'Unexpected publication lookup result',
              );
            }
            return publication;
          })
          .toList(growable: false);
    },
  );

  static TableGroupProfileShareState _state(Object? raw, String expectedId) {
    final json = _map(raw);
    final tableGroupId = _id(json['tableGroupId']);
    final published = _bool(json['publishedOnProfile']);
    final shareId = json['shareId'] == null ? null : _id(json['shareId']);
    final publishedAt = json['publishedAt'] == null
        ? null
        : _instant(json['publishedAt']);
    final note = _note(json['note']);
    if (tableGroupId != expectedId ||
        (published && (shareId == null || publishedAt == null)) ||
        (!published &&
            (shareId != null || note != null || publishedAt != null))) {
      throw const FormatException('Inconsistent profile publication');
    }
    final source = json['tableGroup'] == null
        ? null
        : _source(json['tableGroup']);
    if (source != null && source.id != tableGroupId) {
      throw const FormatException('Wrong table source');
    }
    if (_bool(json['canPublish']) &&
        (source == null || source.status != 'ACTIVE')) {
      throw const FormatException('Publishable table source is not active');
    }
    return TableGroupProfileShareState(
      tableGroupId: tableGroupId,
      shareId: shareId,
      publishedOnProfile: published,
      note: note,
      publishedAt: publishedAt,
      canPublish: _bool(json['canPublish']),
      tableGroup: source,
    );
  }

  static Page<TableGroupProfileShare> _page(Object? raw, int requestedPage) {
    final json = _map(raw);
    final content = json['content'];
    if (content is! List || json['number'] != requestedPage) {
      throw const FormatException('Invalid publication page');
    }
    final last = _bool(json['last']);
    final ids = <String>{};
    final items = content
        .map((raw) {
          final publication = _publication(raw);
          if (!ids.add(publication.shareId)) {
            throw const FormatException('Duplicate publication');
          }
          return publication;
        })
        .toList(growable: false);
    return Page(
      items: items,
      hasNext: !last,
      nextCursor: last ? null : '${requestedPage + 1}',
    );
  }

  static TableGroupProfileShare _publication(Object? raw) {
    final row = _map(raw);
    return TableGroupProfileShare(
      shareId: _id(row['shareId']),
      note: _note(row['note']),
      publishedAt: _instant(row['publishedAt']),
      tableGroup: _source(row['tableGroup']),
      likeCount: _count(row['likeCount']),
      commentCount: _count(row['commentCount']),
      likedByMe: _bool(row['likedByMe']),
    );
  }

  static TableGroupProfileShareSource _source(Object? raw) {
    final json = _map(raw);
    final status = _text(json['status']);
    if (!const {'ACTIVE', 'INACTIVE', 'CANCELLED'}.contains(status)) {
      throw const FormatException('Invalid table status');
    }
    final capacity = _count(json['maxPersonCount']);
    final accepted = _count(json['acceptedCount']);
    if (capacity == 0 || accepted > capacity) {
      throw const FormatException('Invalid table capacity');
    }
    final description = _optionalText(json['description']);
    final meetingAt = json['meetingAt'] == null
        ? null
        : _instant(json['meetingAt']);
    final expiresAt = json['expiresAt'] == null
        ? null
        : _instant(json['expiresAt']);
    if (description == null || meetingAt == null || expiresAt == null) {
      throw const FormatException('Table preview is incomplete');
    }
    return TableGroupProfileShareSource(
      id: _id(json['id']),
      description: description,
      venueName: _optionalText(json['venueName']),
      cityName: _text(json['cityName']),
      districtName: _optionalText(json['districtName']),
      meetingAt: meetingAt,
      expiresAt: expiresAt,
      status: status,
      maxPersonCount: capacity,
      acceptedCount: accepted,
    );
  }

  static int _count(Object? raw) {
    if (raw is! int || raw < 0 || raw > 9007199254740991) {
      throw const FormatException('Invalid count');
    }
    return raw;
  }

  static String _text(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) {
      throw const FormatException('Invalid text');
    }
    return raw.trim();
  }

  static String? _optionalText(Object? raw) {
    if (raw == null) return null;
    if (raw is! String) throw const FormatException('Invalid optional text');
    final value = raw.trim();
    return value.isEmpty ? null : value;
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
    final instant = parseTableGroupWireDate(raw);
    if (instant == null) {
      throw const FormatException('Invalid publication time');
    }
    return instant;
  }
}
