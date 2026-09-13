import '../../core/auth/auth_session_manager.dart';
import '../../core/error/app_error.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../modules/engagement/domain/entities/comment_item.dart';
import '../../modules/engagement/domain/entities/comment_user_summary.dart';
import '../../modules/musician_feed/domain/musician_feed_models.dart';
import '../data/preview_scenario_store.dart';
import '../domain/preview_feed_scenario.dart';

/// An allowlisted RAM transport for the existing production repositories.
/// There is deliberately no HTTP client, URL launcher or fallback delegate.
class PreviewApiClient extends ApiClient {
  PreviewApiClient(this.store, this.sessions);

  final PreviewScenarioStore store;
  final AuthSessionManager sessions;
  int requestCount = 0;
  final List<String> rejectedPaths = [];

  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    final session = sessions.session;
    if ((requestContext?.expectedSessionKey != null &&
            requestContext!.expectedSessionKey != session.userId) ||
        (requestContext?.expectedToken != null &&
            requestContext!.expectedToken != session.token) ||
        requestContext?.requireGuestSession == true) {
      throw ApiException(
        const AppError(
          code: 'preview_session_changed',
          message: 'Önizleme oturumu değişti.',
        ),
      );
    }
    final uri = Uri.tryParse(path);
    if (uri == null ||
        uri.hasScheme ||
        uri.host.isNotEmpty ||
        !uri.path.startsWith('/api/v1/')) {
      return _unsupported(path);
    }
    requestCount++;
    final parameters = <String, dynamic>{...uri.queryParameters, ...?query};
    final parts = uri.pathSegments.skip(2).toList();
    if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
    final result = _resolve(method, parts, body, parameters, path);
    return decoder != null ? decoder(result) : result as T;
  }

  Never _unsupported(String path) {
    rejectedPaths.add(path);
    throw ApiException(
      const AppError(
        code: 'preview_route_unavailable',
        message: 'Bu işlem tasarım önizlemesinde bulunmuyor.',
      ),
    );
  }

  Object? _resolve(
    ApiHttpMethod method,
    List<String> parts,
    Object? body,
    Map<String, dynamic> query,
    String path,
  ) {
    if (parts.isEmpty) return _unsupported(path);
    final input = body is Map ? body : const <String, Object?>{};
    if (parts.length == 4 &&
        parts[0] == 'user' &&
        parts[1] == 'media' &&
        parts[3] == 'access-url' &&
        method == ApiHttpMethod.get) {
      final media = store.mediaReferences[parts[2]];
      if (media == null) return _unsupported(path);
      final expires = DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 5))
          .toIso8601String();
      return {
        'assetId': parts[2],
        'accessUrl': media.url,
        'expiresAt': expires,
        'thumbnailAccessUrl': media.thumbnailUrl,
        'thumbnailExpiresAt': media.thumbnailUrl == null ? null : expires,
        'streamingProtocol': media.kind == 'VIDEO' ? 'PROGRESSIVE' : null,
      };
    }
    if (parts[0] == 'likes' && parts.length >= 3) {
      if (parts.length > 4) return _unsupported(path);
      final type = parts[1];
      final id = parts[2];
      final action = parts.length == 4 ? parts[3] : null;
      if (type == 'COMMENT') {
        if (method == ApiHttpMethod.post || method == ApiHttpMethod.delete) {
          if (action != null) return _unsupported(path);
          store.setCommentLiked(id, method == ApiHttpMethod.post);
        } else if (method != ApiHttpMethod.get || action != 'state') {
          return _unsupported(path);
        }
        final comment = store.commentById(id);
        if (comment == null) return _unsupported(path);
        return {'likeCount': comment.likeCount, 'likedByMe': comment.likedByMe};
      }
      final item = _target(type, id);
      if (item == null) return _unsupported(path);
      if (method == ApiHttpMethod.post || method == ApiHttpMethod.delete) {
        if (action != null) return _unsupported(path);
        store.setLiked(item.id, method == ApiHttpMethod.post);
        return null;
      }
      if (method != ApiHttpMethod.get) return _unsupported(path);
      final engagement = item.engagement;
      if (action == 'count') return engagement?.likeCount ?? 0;
      if (action == 'is-liked') return engagement?.likedByMe ?? false;
      if (action == 'users') {
        final people = <String, CommentUserSummary>{};
        if (engagement?.likedByMe == true) {
          people[previewViewerUserId] = const CommentUserSummary(
            id: previewViewerUserId,
            username: previewViewerUsername,
            avatarUrl: '$previewMediaBaseUrl/avatar-0.png',
          );
        }
        for (final scenario in store.catalogue) {
          final author = scenario.item.author;
          if (author != null &&
              author.userId != null &&
              author.userId != previewViewerUserId) {
            people[author.userId!] = CommentUserSummary(
              id: author.userId!,
              username: author.visibleName,
              avatarUrl: author.avatarUrl,
            );
          }
        }
        final count = engagement?.likeCount ?? 0;
        final offset = _integer(query['cursor'], 0).clamp(0, count);
        final size = _integer(query['size'], 20).clamp(1, 50);
        final end = (offset + size).clamp(0, count);
        final known = people.values.toList();
        const names = [
          'elif_bas',
          'mert_davul',
          'duru_tuslar',
          'ege_ritim',
          'cem_melodiler',
          'asli_sahnede',
          'kaan_kayit',
          'ipek_muzik',
        ];
        final rows = <CommentUserSummary>[];
        for (var index = offset; index < end; index++) {
          rows.add(
            index < known.length
                ? known[index]
                : CommentUserSummary(
                    id: previewUuid('like-${item.id}-$index'),
                    username:
                        '${names[index % names.length]}_${index ~/ names.length + 1}',
                    avatarUrl: '$previewMediaBaseUrl/avatar-${index % 6}.png',
                  ),
          );
        }
        return {
          'items': rows.map(_person).toList(),
          'hasMore': end < count,
          'nextCursor': end < count ? '$end' : null,
        };
      }
      return _unsupported(path);
    }
    if (parts[0] == 'comments') {
      if (parts.length == 2 && method == ApiHttpMethod.delete) {
        store.deleteComment(parts[1]);
        return null;
      }
      if (parts.length == 3 &&
          parts[1] == 'replies' &&
          method == ApiHttpMethod.get) {
        final parent = parts[2];
        final rows = _allComments.where((row) => row.parentCommentId == parent);
        return _commentsPage(rows.toList(), query);
      }
      if (parts.length != 3) return _unsupported(path);
      final item = _target(parts[1], parts[2]);
      if (item == null) return _unsupported(path);
      if (method == ApiHttpMethod.post) {
        return _comment(
          store.addComment(
            item.id,
            input['text'] as String? ?? '',
            parentCommentId: input['parentCommentId'] as String?,
          ),
        );
      }
      if (method == ApiHttpMethod.get) {
        return _commentsPage(
          store
              .commentsFor(item.id)
              .where((row) => row.parentCommentId == null)
              .toList(),
          query,
        );
      }
      return _unsupported(path);
    }
    if (parts[0] == 'follow') {
      if (method == ApiHttpMethod.post &&
          (parts.length == 1 ||
              (parts.length == 2 && parts[1] == 'unfollow'))) {
        final id = input['followingId'] as String?;
        final profile = _profileForUser(id);
        if (profile == null) return _unsupported(path);
        store.setFollowed(
          profile.profileType,
          profile.profileId,
          parts.length == 1,
        );
        return null;
      }
      if (method == ApiHttpMethod.get && parts.length >= 2) {
        if (parts[1] == 'is-following') {
          return _profileForUser(
                query['followingId'] as String?,
              )?.followedByViewer ??
              false;
        }
        if (parts[1] == 'count-followers') return 128;
        if (parts[1] == 'count-following') return 46;
      }
      return _unsupported(path);
    }
    if (parts[0] == 'band-follows' &&
        parts.length >= 3 &&
        parts[1] == 'bands') {
      final id = parts[2];
      if (parts.length == 3 &&
          (method == ApiHttpMethod.post || method == ApiHttpMethod.delete)) {
        store.setFollowed('BAND', id, method == ApiHttpMethod.post);
        return null;
      }
      if (method == ApiHttpMethod.get &&
          parts.length == 4 &&
          parts[3] == 'is-following') {
        return _profiles
                .where((profile) => profile.profileId == id)
                .firstOrNull
                ?.followedByViewer ??
            false;
      }
      if (method == ApiHttpMethod.get &&
          parts.length == 5 &&
          parts[3] == 'followers' &&
          parts[4] == 'count') {
        return 342;
      }
      return _unsupported(path);
    }
    if (parts[0] == 'collabs' && parts.length >= 2) {
      final item = _items
          .where(
            (item) =>
                item.payload is CollabFeedPayload &&
                (item.payload as CollabFeedPayload).listing['id'] == parts[1],
          )
          .firstOrNull;
      if (item == null) return _unsupported(path);
      if (parts.length == 2 && method == ApiHttpMethod.get) {
        return (item.payload as CollabFeedPayload).listing;
      }
      if (parts.length == 3 &&
          parts[2] == 'saved' &&
          (method == ApiHttpMethod.put || method == ApiHttpMethod.delete)) {
        store.setSaved(item.id, method == ApiHttpMethod.put);
        return null;
      }
      return _unsupported(path);
    }
    if (parts[0] == 'announcements' && method == ApiHttpMethod.get) {
      final announcements =
          _items
              .where((item) => item.payload is AnnouncementFeedPayload)
              .fold<Map<String, MusicianFeedItem>>({}, (all, item) {
                all[(item.payload as AnnouncementFeedPayload).announcement.id] =
                    item;
                return all;
              })
              .values
              .toList()
            ..sort(
              (a, b) => (b.payload as AnnouncementFeedPayload)
                  .announcement
                  .createdAt
                  .compareTo(
                    (a.payload as AnnouncementFeedPayload)
                        .announcement
                        .createdAt,
                  ),
            );
      if (parts.length == 2) {
        final item = announcements
            .where(
              (item) =>
                  (item.payload as AnnouncementFeedPayload).announcement.id ==
                  parts[1],
            )
            .firstOrNull;
        return item == null ? _unsupported(path) : _announcement(item);
      }
      if (parts.length == 1) {
        final offset = int.tryParse('${query['cursor'] ?? 0}') ?? 0;
        final limit = _integer(query['limit'], 20).clamp(1, 50);
        final end = (offset + limit).clamp(0, announcements.length);
        return {
          'items': announcements
              .skip(offset)
              .take(limit)
              .map(_announcement)
              .toList(),
          'hasMore': end < announcements.length,
          'nextCursor': end < announcements.length ? '$end' : null,
        };
      }
    }
    return _unsupported(path);
  }

  Iterable<MusicianFeedItem> get _items =>
      store.catalogue.map((scenario) => scenario.item);
  Iterable<ProfileFeedPayload> get _profiles sync* {
    for (final item in _items) {
      final payload = item.payload;
      if (payload is ProfileFeedPayload) yield payload;
      if (payload is ActivityFeedPayload &&
          payload.targetPayload is ProfileFeedPayload) {
        yield payload.targetPayload as ProfileFeedPayload;
      }
    }
  }

  ProfileFeedPayload? _profileForUser(String? id) =>
      _profiles.where((profile) => profile.userId == id).firstOrNull;
  MusicianFeedItem? _target(String type, String id) =>
      store.scenariosByTarget(type, id).firstOrNull?.item;
  Iterable<CommentItem> get _allComments {
    final rows = <String, CommentItem>{};
    for (final item in _items) {
      for (final comment in store.commentsFor(item.id)) {
        rows[comment.id] = comment;
      }
    }
    return rows.values;
  }

  Map<String, Object?> _announcement(MusicianFeedItem item) {
    final value = (item.payload as AnnouncementFeedPayload).announcement;
    final media = value.media;
    final engagement = item.engagement;
    return {
      'id': value.id,
      'version': value.version,
      'title': value.title,
      'body': value.body,
      'targetProfiles': value.targetProfiles.toList(),
      'status': value.status.wireValue,
      'startsAt': value.startsAt?.toIso8601String(),
      'endsAt': value.endsAt?.toIso8601String(),
      'firstPublishedAt': value.firstPublishedAt?.toIso8601String(),
      'createdAt': value.createdAt.toIso8601String(),
      'updatedAt': value.updatedAt.toIso8601String(),
      'media': media == null
          ? null
          : {
              'assetId': media.assetId,
              'kind': media.kind,
              'status': media.status,
              'streamingProtocol': media.streamingProtocol,
              'width': media.width,
              'height': media.height,
              'durationSeconds': media.durationSeconds,
            },
      'engagement': {
        'likeCount': engagement?.likeCount ?? value.engagement.likeCount,
        'commentCount':
            engagement?.commentCount ?? value.engagement.commentCount,
        'likedByMe': engagement?.likedByMe ?? value.engagement.likedByMe,
      },
      'feedHidden': store.isHidden(item.id),
    };
  }

  Map<String, Object?> _commentsPage(
    List<CommentItem> rows,
    Map<String, dynamic> query,
  ) {
    final liveParents = _allComments
        .where((row) => !row.deleted)
        .map((row) => row.parentCommentId)
        .whereType<String>()
        .toSet();
    final visible = rows
        .where((row) => !row.deleted || liveParents.contains(row.id))
        .toList();
    final ascending = query['sort'] == 'createdAt,asc';
    visible.sort((a, b) {
      final byTime = (a.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(
        b.createdAt?.millisecondsSinceEpoch ?? 0,
      );
      final comparison = byTime == 0 ? a.id.compareTo(b.id) : byTime;
      return ascending ? comparison : -comparison;
    });
    final page = _integer(query['page'], 0).clamp(0, 1000);
    final size = _integer(query['size'], 20).clamp(1, 50);
    return {
      'content': visible.skip(page * size).take(size).map(_comment).toList(),
      'totalElements': visible.length,
      'number': page,
      'size': size,
    };
  }

  static int _integer(Object? raw, int fallback) =>
      raw is int ? raw : int.tryParse('$raw') ?? fallback;
  static Map<String, Object?> _person(CommentUserSummary person) => {
    'id': person.id,
    'username': person.username,
    'avatarUrl': person.avatarUrl,
    'visibilityMode': person.visibilityMode.wireValue,
  };
  static Map<String, Object?> _comment(CommentItem row) => {
    'id': row.id,
    'user': _person(row.user),
    'anonymousAuthor': row.anonymousAuthor,
    'text': row.text,
    'deleted': row.deleted,
    'parentCommentId': row.parentCommentId,
    'replyCount': row.replyCount,
    'createdAt': row.createdAt?.toIso8601String(),
    'likeCount': row.likeCount,
    'likedByMe': row.likedByMe,
  };

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
  }) => request(ApiHttpMethod.get, path, query: query, decoder: decoder);
  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => request(ApiHttpMethod.post, path, body: body, decoder: decoder);
  @override
  Future<T> put<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => request(ApiHttpMethod.put, path, body: body, decoder: decoder);
  @override
  Future<T> patch<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => request(ApiHttpMethod.patch, path, body: body, decoder: decoder);
  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    T Function(Object? json)? decoder,
  }) => request(ApiHttpMethod.delete, path, body: body, decoder: decoder);
}
