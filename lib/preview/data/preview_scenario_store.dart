import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../modules/engagement/domain/entities/comment_item.dart';
import '../../modules/engagement/domain/entities/comment_user_summary.dart';
import '../../modules/musician_feed/domain/musician_feed_models.dart';
import '../../modules/promotion/domain/entities/announcement.dart';
import '../domain/preview_feed_scenario.dart';
import 'preview_feed_catalogue.dart';

/// A process-local design workspace. It never opens storage or a network client.
/// The fixed catalogue bounds the sample data, including every displayed comment.
class PreviewScenarioStore extends ChangeNotifier {
  PreviewScenarioStore({DateTime? now})
    : _now = (now ?? DateTime.now()).toUtc() {
    _baseline = buildPreviewFeedCatalogue(now: _now);
    _mixedIds = _arrangeMixedFeed(_baseline);
    _restore();
  }

  final DateTime _now;
  late final List<PreviewFeedScenario> _baseline;
  late final List<String> _mixedIds;
  final _items = <String, MusicianFeedItem>{};
  final _hidden = <String>{};
  final _muted = <MusicianFeedAuthorProfileIdentity>{};
  final _comments = <String, List<CommentItem>>{};
  int _commentSequence = 0;

  List<PreviewFeedScenario> get catalogue => List.unmodifiable(
    _baseline.map((scenario) => scenario.withItem(_items[scenario.item.id]!)),
  );
  List<PreviewFeedScenario> get mixedFeed =>
      List.unmodifiable(_mixedIds.map((id) => scenarioById(id)!));
  List<PreviewFeedScenario> get visibleMixedFeed => List.unmodifiable(
    mixedFeed.where(
      (scenario) =>
          !isHidden(scenario.item.id) &&
          !_muted.contains(
            musicianFeedAuthorProfileIdentity(scenario.item.author),
          ),
    ),
  );
  Set<String> get hiddenItemIds => Set.unmodifiable(_hidden);
  Set<MusicianFeedAuthorProfileIdentity> get mutedAuthors =>
      Set.unmodifiable(_muted);

  PreviewFeedScenario? scenarioById(String id) {
    for (final scenario in _baseline) {
      if (scenario.id == id || scenario.item.id == id) {
        return scenario.withItem(_items[scenario.item.id]!);
      }
    }
    return null;
  }

  MusicianFeedItem? itemById(String id) => _items[id] ?? scenarioById(id)?.item;

  List<PreviewFeedScenario> scenariosByTarget(
    String targetType,
    String targetId,
  ) => List.unmodifiable(
    catalogue.where(
      (scenario) =>
          _targetKey(scenario.item) == '${targetType.toUpperCase()}:$targetId',
    ),
  );

  bool isHidden(String itemId) =>
      _hidden.contains(itemById(itemId)?.id ?? itemId);

  Map<String, PreviewMediaReference> get mediaReferences {
    final result = <String, PreviewMediaReference>{};
    void collect(MusicianFeedPayload payload) {
      if (payload is TrackFeedPayload && payload.playbackUrl != null) {
        result[payload.mediaAssetId] = PreviewMediaReference(
          url: payload.playbackUrl!,
          kind: 'AUDIO',
        );
      } else if (payload is ProfileMediaFeedPayload) {
        final url = payload.playbackUrl ?? payload.displayUrl;
        if (url != null) {
          result[payload.mediaAssetId] = PreviewMediaReference(
            url: url,
            kind: payload.kind,
            thumbnailUrl: payload.thumbnailUrl,
          );
        }
      } else if (payload is AnnouncementFeedPayload) {
        final media = payload.announcement.media;
        if (media != null) {
          result[media.assetId] = PreviewMediaReference(
            url:
                '$previewMediaBaseUrl/${media.isVideo ? 'video.mp4' : 'announcement-image.png'}',
            kind: media.kind,
            thumbnailUrl:
                '$previewMediaBaseUrl/announcement-${media.isVideo ? 'video' : 'image'}.png',
          );
        }
      } else if (payload is ActivityFeedPayload) {
        collect(payload.targetPayload);
      }
    }

    for (final item in _items.values) {
      collect(item.payload);
    }
    return Map.unmodifiable(result);
  }

  void setLiked(String itemId, bool liked) {
    final item = itemById(itemId);
    final engagement = item?.engagement;
    if (item == null ||
        engagement == null ||
        !engagement.likable ||
        engagement.likedByMe == liked) {
      return;
    }
    _changeEngagement(
      _targetKey(item),
      (old) => old.copyWith(
        likedByMe: liked,
        likeCount: math.max(0, old.likeCount + (liked ? 1 : -1)),
      ),
    );
    notifyListeners();
  }

  void toggleLike(String itemId) =>
      setLiked(itemId, !(itemById(itemId)?.engagement?.likedByMe ?? false));

  void setSaved(String itemId, bool saved) {
    final item = itemById(itemId);
    if (item == null || item.payload is! CollabFeedPayload) return;
    final key = _targetKey(item);
    var changed = false;
    for (final entry in _items.entries.toList()) {
      final payload = entry.value.payload;
      if (_targetKey(entry.value) == key &&
          payload is CollabFeedPayload &&
          payload.listing['savedByMe'] != saved) {
        _items[entry.key] = entry.value.copyWith(
          payload: CollabFeedPayload(
            listing: Map.unmodifiable({...payload.listing, 'savedByMe': saved}),
          ),
        );
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void setFollowed(String profileType, String profileId, bool followed) {
    final identity = parseMusicianFeedAuthorProfileIdentity(
      profileType: profileType,
      profileId: profileId,
    );
    if (identity == null) return;
    MusicianFeedActor updateActor(MusicianFeedActor actor) =>
        musicianFeedAuthorProfileIdentity(actor) != identity
        ? actor
        : MusicianFeedActor(
            userId: actor.userId,
            profileId: actor.profileId,
            profileType: actor.profileType,
            username: actor.username,
            displayName: actor.displayName,
            avatarUrl: actor.avatarUrl,
            followedByViewer: followed,
          );
    MusicianFeedPayload updatePayload(MusicianFeedPayload payload) {
      if (payload is ProfileFeedPayload &&
          payload.profileType == identity.profileType &&
          payload.profileId == identity.profileId) {
        return payload.copyWith(followedByViewer: followed);
      }
      if (payload is ActivityFeedPayload) {
        return ActivityFeedPayload(
          action: payload.action,
          actor: updateActor(payload.actor),
          targetItemType: payload.targetItemType,
          targetPayload: updatePayload(payload.targetPayload),
        );
      }
      return payload;
    }

    for (final item in _items.values.toList()) {
      _items[item.id] = MusicianFeedItem(
        id: item.id,
        type: item.type,
        payloadVersion: item.payloadVersion,
        occurredAt: item.occurredAt,
        position: item.position,
        impressionToken: item.impressionToken,
        reason: MusicianFeedReason(
          code: item.reason.code,
          actors: List.unmodifiable(item.reason.actors.map(updateActor)),
          secondaryActorCount: item.reason.secondaryActorCount,
        ),
        author: item.author == null ? null : updateActor(item.author!),
        target: item.target,
        engagement: item.engagement,
        promotion: item.promotion,
        feedbackCapabilities: item.feedbackCapabilities,
        payload: updatePayload(item.payload),
      );
    }
    notifyListeners();
  }

  void hide(String itemId) {
    final item = itemById(itemId);
    if (item == null || !_hidden.add(item.id)) return;
    if (item.payload case final AnnouncementFeedPayload payload) {
      _items[item.id] = item.copyWith(
        payload: AnnouncementFeedPayload(
          _announcement(payload.announcement, hidden: true),
        ),
      );
    }
    notifyListeners();
  }

  /// Design feedback removes this card locally; it does not simulate ranking.
  void showLess(String itemId) => hide(itemId);

  void mute(String profileType, String profileId) {
    final identity = parseMusicianFeedAuthorProfileIdentity(
      profileType: profileType,
      profileId: profileId,
    );
    if (identity != null && _muted.add(identity)) notifyListeners();
  }

  void unmute(String profileType, String profileId) {
    final identity = parseMusicianFeedAuthorProfileIdentity(
      profileType: profileType,
      profileId: profileId,
    );
    if (identity != null && _muted.remove(identity)) notifyListeners();
  }

  List<CommentItem> commentsFor(String itemId) {
    final item = itemById(itemId);
    return item == null
        ? const []
        : List.unmodifiable(
            _comments[_targetKey(item)] ?? const <CommentItem>[],
          );
  }

  CommentItem? commentById(String id) {
    for (final comments in _comments.values) {
      for (final comment in comments) {
        if (comment.id == id) return comment;
      }
    }
    return null;
  }

  CommentItem addComment(
    String itemId,
    String text, {
    String? parentCommentId,
  }) {
    final item = itemById(itemId);
    if (item == null || !(item.engagement?.commentable ?? false)) {
      throw ArgumentError.value(
        itemId,
        'itemId',
        'Bu kart yorumları desteklemiyor.',
      );
    }
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Yorum boş olamaz.');
    }
    final key = _targetKey(item);
    final comments = _comments.putIfAbsent(key, () => []);
    final parentIndex = parentCommentId == null
        ? -1
        : comments.indexWhere((c) => c.id == parentCommentId);
    if (parentCommentId != null &&
        (parentIndex < 0 || comments[parentIndex].deleted)) {
      throw ArgumentError.value(
        parentCommentId,
        'parentCommentId',
        'Yorum bu içeriğe ait değil.',
      );
    }
    final comment = CommentItem(
      id: previewUuid('new-comment-${++_commentSequence}'),
      user: const CommentUserSummary(
        id: previewViewerUserId,
        username: previewViewerUsername,
        avatarUrl: '$previewMediaBaseUrl/avatar-0.png',
      ),
      text: normalized,
      deleted: false,
      parentCommentId: parentCommentId,
      replyCount: 0,
      createdAt: _now.add(Duration(seconds: _commentSequence)),
    );
    comments.add(comment);
    if (parentIndex >= 0) {
      comments[parentIndex] = _comment(
        comments[parentIndex],
        replyCount: comments[parentIndex].replyCount + 1,
      );
    }
    _changeEngagement(
      key,
      (old) => old.copyWith(commentCount: old.commentCount + 1),
    );
    notifyListeners();
    return comment;
  }

  CommentItem? deleteComment(String id) {
    for (final entry in _comments.entries) {
      final index = entry.value.indexWhere((c) => c.id == id);
      if (index < 0) continue;
      final old = entry.value[index];
      if (old.deleted) return old;
      final updated = _comment(old, deleted: true);
      entry.value[index] = updated;
      final parentIndex = entry.value.indexWhere(
        (c) => c.id == old.parentCommentId,
      );
      if (parentIndex >= 0) {
        final parent = entry.value[parentIndex];
        entry.value[parentIndex] = _comment(
          parent,
          replyCount: math.max(0, parent.replyCount - 1),
        );
      }
      _changeEngagement(
        entry.key,
        (old) => old.copyWith(commentCount: math.max(0, old.commentCount - 1)),
      );
      notifyListeners();
      return updated;
    }
    return null;
  }

  CommentItem? setCommentLiked(String id, bool liked) {
    for (final comments in _comments.values) {
      final index = comments.indexWhere((c) => c.id == id);
      if (index < 0) continue;
      final old = comments[index];
      if (old.deleted || old.likedByMe == liked) return old;
      final updated = _comment(
        old,
        likedByMe: liked,
        likeCount: math.max(0, old.likeCount + (liked ? 1 : -1)),
      );
      comments[index] = updated;
      notifyListeners();
      return updated;
    }
    return null;
  }

  void reset() {
    _restore();
    notifyListeners();
  }

  void _restore() {
    _hidden.clear();
    _muted.clear();
    _comments.clear();
    _items.clear();
    _commentSequence = 0;
    for (final scenario in _baseline) {
      final item = scenario.item;
      _items[item.id] = item;
      final count = item.engagement?.commentCount ?? 0;
      if (count == 0) continue;
      _comments.putIfAbsent(
        _targetKey(item),
        () => [
          for (var index = 0; index < count; index++)
            CommentItem(
              id: previewUuid('${_targetKey(item)}-comment-$index'),
              user: CommentUserSummary(
                id: index == 2
                    ? previewViewerUserId
                    : previewUuid('user-${index % 6}'),
                username: index == 2
                    ? previewViewerUsername
                    : [
                        'ada_gitar',
                        'selin_vokal',
                        'kiyi_kolektif',
                        'kiyi_sahne',
                        'ece_dinliyor',
                        'oda_studyo',
                      ][index % 6],
                avatarUrl:
                    '$previewMediaBaseUrl/avatar-${index == 2 ? 0 : index % 6}.png',
              ),
              text: [
                'Bu enerji çok iyi, devamını merakla bekliyorum.',
                'Bir sonraki buluşmada ben de varım! 🎶',
                'Birlikte üretmek güzel.',
                'Gitarın tonu kayda çok yakışmış.',
                'Canlı dinlemek için sabırsızlanıyorum.',
                'Kayıt sürecini de paylaşır mısınız?',
                'Yeni düzenleme gerçekten iyi olmuş.',
                'Bu bölümü tekrar tekrar dinledim.',
              ][index % 8],
              deleted: false,
              parentCommentId: null,
              replyCount: 0,
              createdAt: _now.subtract(Duration(minutes: 12 + index * 7)),
              likeCount: index == 0 ? 8 : 2,
            ),
        ],
      );
    }
  }

  void _changeEngagement(
    String key,
    MusicianFeedEngagement Function(MusicianFeedEngagement) change,
  ) {
    for (final item in _items.values.toList()) {
      if (_targetKey(item) != key || item.engagement == null) continue;
      final engagement = change(item.engagement!);
      final payload = item.payload;
      _items[item.id] = item.copyWith(
        engagement: engagement,
        payload: payload is AnnouncementFeedPayload
            ? AnnouncementFeedPayload(
                _announcement(
                  payload.announcement,
                  engagement: AnnouncementEngagement(
                    likeCount: engagement.likeCount,
                    commentCount: engagement.commentCount,
                    likedByMe: engagement.likedByMe,
                  ),
                ),
              )
            : payload,
      );
    }
  }

  static String _targetKey(MusicianFeedItem item) => item.engagement != null
      ? '${item.engagement!.targetType}:${item.engagement!.targetId}'
      : item.target != null
      ? '${item.target!.type}:${item.target!.id}'
      : item.id;

  static Announcement _announcement(
    Announcement value, {
    bool? hidden,
    AnnouncementEngagement? engagement,
  }) => Announcement(
    id: value.id,
    version: value.version,
    title: value.title,
    body: value.body,
    targetProfiles: value.targetProfiles,
    status: value.status,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
    startsAt: value.startsAt,
    endsAt: value.endsAt,
    firstPublishedAt: value.firstPublishedAt,
    media: value.media,
    engagement: engagement ?? value.engagement,
    feedHidden: hidden ?? value.feedHidden,
  );

  static CommentItem _comment(
    CommentItem value, {
    bool? deleted,
    int? replyCount,
    int? likeCount,
    bool? likedByMe,
  }) => CommentItem(
    id: value.id,
    user: value.user,
    anonymousAuthor: value.anonymousAuthor,
    text: (deleted ?? value.deleted) ? '' : value.text,
    deleted: deleted ?? value.deleted,
    parentCommentId: value.parentCommentId,
    replyCount: replyCount ?? value.replyCount,
    createdAt: value.createdAt,
    likeCount: likeCount ?? value.likeCount,
    likedByMe: likedByMe ?? value.likedByMe,
  );

  static List<String> _arrangeMixedFeed(List<PreviewFeedScenario> catalogue) {
    final eligible = catalogue.where((s) => s.includeInMixedFeed).toList();
    final announcements = eligible
        .where((s) => s.item.type == MusicianFeedItemType.announcement)
        .toList();
    final promotions = eligible.where((s) => s.item.promotion != null).toList();
    final groups = <String, List<PreviewFeedScenario>>{};
    for (final scenario in eligible.where(
      (s) =>
          s.item.type != MusicianFeedItemType.announcement &&
          s.item.promotion == null,
    )) {
      groups.putIfAbsent(scenario.category, () => []).add(scenario);
    }
    final organic = <PreviewFeedScenario>[];
    for (
      var round = 0;
      groups.values.any((items) => round < items.length);
      round++
    ) {
      for (final items in groups.values) {
        if (round < items.length) organic.add(items[round]);
      }
    }
    // A fixed visual composition, not a representation of recommendation scores.
    final insertions = <int, PreviewFeedScenario>{
      2: announcements[0],
      7: promotions[0],
      12: promotions[1],
      17: announcements[1],
      23: promotions[2],
      29: promotions[3],
      35: announcements[2],
      42: promotions[4],
    };
    return List.unmodifiable([
      for (final entry in organic.indexed) ...[
        entry.$2.id,
        if (insertions[entry.$1 + 1] case final scenario?) scenario.id,
      ],
    ]);
  }
}
