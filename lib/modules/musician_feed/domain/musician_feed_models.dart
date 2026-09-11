import 'dart:collection';

const int musicianFeedSchemaVersion = 1;
const Set<String> musicianFeedAuthorProfileTypes = {
  'MUSICIAN',
  'LISTENER',
  'STUDIO',
  'VENUE',
  'BAND',
};

typedef MusicianFeedAuthorProfileIdentity = ({
  String profileType,
  String profileId,
});

final RegExp _unsafeMusicianFeedProfileId = RegExp(r'[/\\\u0000-\u001F\u007F]');

MusicianFeedAuthorProfileIdentity? parseMusicianFeedAuthorProfileIdentity({
  required String profileType,
  required String profileId,
}) {
  final normalizedType = profileType.trim().toUpperCase();
  final normalizedId = profileId.trim();
  if (!musicianFeedAuthorProfileTypes.contains(normalizedType) ||
      normalizedId.isEmpty ||
      normalizedId.length > 128 ||
      _unsafeMusicianFeedProfileId.hasMatch(normalizedId)) {
    return null;
  }
  return (profileType: normalizedType, profileId: normalizedId);
}

enum MusicianFeedItemType {
  track('TRACK'),
  profileMedia('PROFILE_MEDIA'),
  collab('COLLAB'),
  event('EVENT'),
  eventProfileShare('EVENT_PROFILE_SHARE'),
  overthinkingProfileShare('OVERTHINKING_PROFILE_SHARE'),
  tableGroupProfileShare('TABLEGROUP_PROFILE_SHARE'),
  activityFollow('ACTIVITY_FOLLOW'),
  activityLike('ACTIVITY_LIKE'),
  activityComment('ACTIVITY_COMMENT'),
  profile('PROFILE'),
  profileCompletion('PROFILE_COMPLETION'),
  sponsored('SPONSORED');

  const MusicianFeedItemType(this.apiValue);
  final String apiValue;

  static MusicianFeedItemType parse(Object? value, String path) {
    final normalized = _requiredText(value, path).toUpperCase();
    return values.firstWhere(
      (item) => item.apiValue == normalized,
      orElse: () => throw MusicianFeedFormatException(
        '$path contains an unsupported feed item type',
      ),
    );
  }
}

enum MusicianFeedFeedbackAction {
  hide('HIDE'),
  showLess('SHOW_LESS'),
  report('REPORT');

  const MusicianFeedFeedbackAction(this.apiValue);
  final String apiValue;

  static MusicianFeedFeedbackAction? tryParse(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim().toUpperCase();
    for (final action in values) {
      if (action.apiValue == normalized) return action;
    }
    return null;
  }
}

enum MusicianFeedTelemetryEventType {
  impression('IMPRESSION'),
  open('OPEN'),
  cta('CTA'),
  follow('FOLLOW'),
  save('SAVE'),
  apply('APPLY'),
  hide('HIDE'),
  mute('MUTE'),
  report('REPORT');

  const MusicianFeedTelemetryEventType(this.apiValue);
  final String apiValue;
}

class MusicianFeedPage {
  const MusicianFeedPage({
    required this.schemaVersion,
    required this.algorithmVersion,
    required this.feedSessionId,
    required this.generatedAt,
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final int schemaVersion;
  final String algorithmVersion;
  final String feedSessionId;
  final DateTime generatedAt;
  final List<MusicianFeedItem> items;
  final String? nextCursor;
  final bool hasMore;

  factory MusicianFeedPage.fromJson(Object? json) {
    final map = _object(json, 'feed');
    final schemaVersion = _requiredInt(map['schemaVersion'], 'schemaVersion');
    if (schemaVersion != musicianFeedSchemaVersion) {
      throw MusicianFeedFormatException(
        'Unsupported musician feed schema version: $schemaVersion',
      );
    }
    final rawItems = map['items'];
    if (rawItems is! List) {
      throw const MusicianFeedFormatException('items must be a list');
    }
    final hasMore = _requiredBool(map['hasMore'], 'hasMore');
    final cursor = _optionalText(map['nextCursor'], 'nextCursor');
    if (hasMore && cursor == null) {
      throw const MusicianFeedFormatException(
        'nextCursor is required while hasMore is true',
      );
    }
    return MusicianFeedPage(
      schemaVersion: schemaVersion,
      algorithmVersion: _requiredText(
        map['algorithmVersion'],
        'algorithmVersion',
      ),
      feedSessionId: _requiredText(map['feedSessionId'], 'feedSessionId'),
      generatedAt: _requiredDate(map['generatedAt'], 'generatedAt'),
      items: List.unmodifiable(
        rawItems.indexed.map(
          (entry) =>
              MusicianFeedItem.fromJson(entry.$2, path: 'items[${entry.$1}]'),
        ),
      ),
      nextCursor: cursor,
      hasMore: hasMore,
    );
  }
}

class MusicianFeedItem {
  const MusicianFeedItem({
    required this.id,
    required this.type,
    required this.payloadVersion,
    required this.occurredAt,
    required this.position,
    required this.impressionToken,
    required this.reason,
    required this.author,
    required this.target,
    required this.engagement,
    required this.promotion,
    required this.feedbackCapabilities,
    required this.payload,
  });

  final String id;
  final MusicianFeedItemType type;
  final int payloadVersion;
  final DateTime occurredAt;
  final int position;
  final String impressionToken;
  final MusicianFeedReason reason;
  final MusicianFeedActor? author;
  final MusicianFeedTarget? target;
  final MusicianFeedEngagement? engagement;
  final MusicianFeedPromotion? promotion;
  final Set<MusicianFeedFeedbackAction> feedbackCapabilities;
  final MusicianFeedPayload payload;

  factory MusicianFeedItem.fromJson(Object? json, {String path = 'item'}) {
    final map = _object(json, path);
    final type = MusicianFeedItemType.parse(map['type'], '$path.type');
    final payloadVersion = _requiredInt(
      map['payloadVersion'],
      '$path.payloadVersion',
    );
    if (payloadVersion != 1) {
      throw MusicianFeedFormatException(
        '$path has unsupported payload version $payloadVersion',
      );
    }
    final rawCapabilities = map['feedbackCapabilities'];
    if (rawCapabilities is! List) {
      throw MusicianFeedFormatException(
        '$path.feedbackCapabilities must be a list',
      );
    }
    final capabilities = <MusicianFeedFeedbackAction>{};
    for (final raw in rawCapabilities) {
      if (raw is! String) {
        throw MusicianFeedFormatException(
          '$path.feedbackCapabilities must contain strings',
        );
      }
      final parsed = MusicianFeedFeedbackAction.tryParse(raw);
      // Capabilities are additive. An older safe client ignores actions it
      // cannot perform instead of making the whole feed unavailable.
      if (parsed != null) capabilities.add(parsed);
    }
    return MusicianFeedItem(
      id: _requiredText(map['id'], '$path.id'),
      type: type,
      payloadVersion: payloadVersion,
      occurredAt: _requiredDate(map['occurredAt'], '$path.occurredAt'),
      position: _requiredNonNegativeInt(map['position'], '$path.position'),
      impressionToken: _requiredBoundedText(
        map['impressionToken'],
        '$path.impressionToken',
        maximumLength: 4096,
      ),
      reason: MusicianFeedReason.fromJson(map['reason'], path: '$path.reason'),
      author: map['author'] == null
          ? null
          : MusicianFeedActor.fromJson(map['author'], path: '$path.author'),
      target: map['target'] == null
          ? null
          : MusicianFeedTarget.fromJson(map['target'], path: '$path.target'),
      engagement: map['engagement'] == null
          ? null
          : MusicianFeedEngagement.fromJson(
              map['engagement'],
              path: '$path.engagement',
            ),
      promotion: map['promotion'] == null
          ? null
          : MusicianFeedPromotion.fromJson(
              map['promotion'],
              path: '$path.promotion',
            ),
      feedbackCapabilities: Set.unmodifiable(capabilities),
      payload: MusicianFeedPayload.parse(type, map['payload'], '$path.payload'),
    );
  }

  MusicianFeedItem copyWith({
    MusicianFeedEngagement? engagement,
    MusicianFeedPayload? payload,
  }) {
    return MusicianFeedItem(
      id: id,
      type: type,
      payloadVersion: payloadVersion,
      occurredAt: occurredAt,
      position: position,
      impressionToken: impressionToken,
      reason: reason,
      author: author,
      target: target,
      engagement: engagement ?? this.engagement,
      promotion: promotion,
      feedbackCapabilities: feedbackCapabilities,
      payload: payload ?? this.payload,
    );
  }
}

class MusicianFeedActor {
  const MusicianFeedActor({
    required this.userId,
    required this.profileId,
    required this.profileType,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.followedByViewer,
  });

  final String? userId;
  final String? profileId;
  final String profileType;
  final String? username;
  final String displayName;
  final String? avatarUrl;
  final bool followedByViewer;

  factory MusicianFeedActor.fromJson(Object? json, {required String path}) {
    final map = _object(json, path);
    return MusicianFeedActor(
      userId: _optionalText(map['userId'], '$path.userId'),
      profileId: _optionalText(map['profileId'], '$path.profileId'),
      profileType: _requiredText(
        map['profileType'],
        '$path.profileType',
      ).toUpperCase(),
      username: _optionalText(map['username'], '$path.username'),
      displayName: _requiredText(map['displayName'], '$path.displayName'),
      avatarUrl: _optionalText(map['avatarUrl'], '$path.avatarUrl'),
      followedByViewer: _requiredBool(
        map['followedByViewer'],
        '$path.followedByViewer',
      ),
    );
  }
}

MusicianFeedAuthorProfileIdentity? musicianFeedAuthorProfileIdentity(
  MusicianFeedActor? author,
) {
  if (author == null) return null;
  return parseMusicianFeedAuthorProfileIdentity(
    profileType: author.profileType,
    profileId: author.profileId ?? '',
  );
}

class MusicianFeedReason {
  const MusicianFeedReason({
    required this.code,
    required this.actors,
    required this.secondaryActorCount,
  });

  final String code;
  final List<MusicianFeedActor> actors;
  final int secondaryActorCount;

  factory MusicianFeedReason.fromJson(Object? json, {required String path}) {
    final map = _object(json, path);
    final rawActors = map['actors'];
    if (rawActors is! List) {
      throw MusicianFeedFormatException('$path.actors must be a list');
    }
    return MusicianFeedReason(
      code: _requiredText(map['code'], '$path.code').toUpperCase(),
      actors: List.unmodifiable(
        rawActors.indexed.map(
          (entry) => MusicianFeedActor.fromJson(
            entry.$2,
            path: '$path.actors[${entry.$1}]',
          ),
        ),
      ),
      secondaryActorCount: _requiredNonNegativeInt(
        map['secondaryActorCount'],
        '$path.secondaryActorCount',
      ),
    );
  }
}

class MusicianFeedTarget {
  const MusicianFeedTarget({required this.type, required this.id});
  final String type;
  final String id;

  factory MusicianFeedTarget.fromJson(Object? json, {required String path}) {
    final map = _object(json, path);
    return MusicianFeedTarget(
      type: _requiredText(map['type'], '$path.type').toUpperCase(),
      id: _requiredText(map['id'], '$path.id'),
    );
  }
}

class MusicianFeedEngagement {
  const MusicianFeedEngagement({
    required this.targetType,
    required this.targetId,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.likable,
    required this.commentable,
  });

  final String targetType;
  final String targetId;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool likable;
  final bool commentable;

  factory MusicianFeedEngagement.fromJson(
    Object? json, {
    required String path,
  }) {
    final map = _object(json, path);
    return MusicianFeedEngagement(
      targetType: _requiredText(
        map['targetType'],
        '$path.targetType',
      ).toUpperCase(),
      targetId: _requiredText(map['targetId'], '$path.targetId'),
      likeCount: _requiredNonNegativeInt(map['likeCount'], '$path.likeCount'),
      commentCount: _requiredNonNegativeInt(
        map['commentCount'],
        '$path.commentCount',
      ),
      likedByMe: _requiredBool(map['likedByMe'], '$path.likedByMe'),
      likable: _requiredBool(map['likable'], '$path.likable'),
      commentable: _requiredBool(map['commentable'], '$path.commentable'),
    );
  }

  MusicianFeedEngagement copyWith({
    bool? likedByMe,
    int? likeCount,
    int? commentCount,
  }) {
    return MusicianFeedEngagement(
      targetType: targetType,
      targetId: targetId,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
      likable: likable,
      commentable: commentable,
    );
  }
}

class MusicianFeedPromotion {
  const MusicianFeedPromotion({
    required this.campaignId,
    required this.disclosure,
    required this.ctaLabel,
    required this.ctaUrl,
  });

  final String? campaignId;
  final String disclosure;
  final String? ctaLabel;
  final String? ctaUrl;

  factory MusicianFeedPromotion.fromJson(Object? json, {required String path}) {
    final map = _object(json, path);
    return MusicianFeedPromotion(
      campaignId: _optionalText(map['campaignId'], '$path.campaignId'),
      disclosure: _requiredText(
        map['disclosure'],
        '$path.disclosure',
      ).toUpperCase(),
      ctaLabel: _optionalText(map['ctaLabel'], '$path.ctaLabel'),
      ctaUrl: _optionalNavigationTarget(map['ctaUrl'], '$path.ctaUrl'),
    );
  }
}

sealed class MusicianFeedPayload {
  const MusicianFeedPayload();

  static MusicianFeedPayload parse(
    MusicianFeedItemType type,
    Object? json,
    String path,
  ) {
    return switch (type) {
      MusicianFeedItemType.track => TrackFeedPayload.fromJson(json, path),
      MusicianFeedItemType.profileMedia => ProfileMediaFeedPayload.fromJson(
        json,
        path,
      ),
      MusicianFeedItemType.collab => CollabFeedPayload.fromJson(json, path),
      MusicianFeedItemType.event || MusicianFeedItemType.eventProfileShare =>
        EventFeedPayload.fromJson(json, path),
      MusicianFeedItemType.overthinkingProfileShare ||
      MusicianFeedItemType.tableGroupProfileShare =>
        ProfileShareFeedPayload.fromJson(json, path),
      MusicianFeedItemType.activityFollow ||
      MusicianFeedItemType.activityLike ||
      MusicianFeedItemType.activityComment => ActivityFeedPayload.fromJson(
        json,
        path,
      ),
      MusicianFeedItemType.profile => ProfileFeedPayload.fromJson(json, path),
      MusicianFeedItemType.profileCompletion => CompletionFeedPayload.fromJson(
        json,
        path,
      ),
      MusicianFeedItemType.sponsored => SponsoredFeedPayload.fromJson(
        json,
        path,
      ),
    };
  }
}

class ProfileFeedPayload extends MusicianFeedPayload {
  const ProfileFeedPayload({
    required this.profileId,
    required this.profileType,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.location,
    required this.followedByViewer,
  });

  final String profileId;
  final String profileType;
  final String? userId;
  final String? username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? location;
  final bool followedByViewer;

  factory ProfileFeedPayload.fromJson(Object? json, String path) {
    final map = _object(json, path);
    return ProfileFeedPayload(
      profileId: _requiredText(map['profileId'], '$path.profileId'),
      profileType: _requiredText(
        map['profileType'],
        '$path.profileType',
      ).toUpperCase(),
      userId: _optionalText(map['userId'], '$path.userId'),
      username: _optionalText(map['username'], '$path.username'),
      displayName: _requiredText(map['displayName'], '$path.displayName'),
      avatarUrl: _optionalHttpUrl(map['avatarUrl'], '$path.avatarUrl'),
      bio: _optionalText(map['bio'], '$path.bio'),
      location: _optionalText(map['location'], '$path.location'),
      followedByViewer: _requiredBool(
        map['followedByViewer'],
        '$path.followedByViewer',
      ),
    );
  }

  ProfileFeedPayload copyWith({bool? followedByViewer}) => ProfileFeedPayload(
    profileId: profileId,
    profileType: profileType,
    userId: userId,
    username: username,
    displayName: displayName,
    avatarUrl: avatarUrl,
    bio: bio,
    location: location,
    followedByViewer: followedByViewer ?? this.followedByViewer,
  );
}

class TrackFeedPayload extends MusicianFeedPayload {
  const TrackFeedPayload({
    required this.trackId,
    required this.mediaAssetId,
    required this.title,
    required this.playbackUrl,
    required this.durationSeconds,
    required this.bpm,
  });

  final String trackId;
  final String mediaAssetId;
  final String title;
  final String? playbackUrl;
  final int? durationSeconds;
  final int? bpm;

  factory TrackFeedPayload.fromJson(Object? json, String path) {
    final map = _object(json, path);
    return TrackFeedPayload(
      trackId: _requiredText(map['trackId'], '$path.trackId'),
      mediaAssetId: _requiredText(map['mediaAssetId'], '$path.mediaAssetId'),
      title: _requiredText(map['title'], '$path.title'),
      playbackUrl: _optionalHttpUrl(map['playbackUrl'], '$path.playbackUrl'),
      durationSeconds: _optionalNonNegativeInt(
        map['durationSeconds'],
        '$path.durationSeconds',
      ),
      bpm: _optionalNonNegativeInt(map['bpm'], '$path.bpm'),
    );
  }
}

class ProfileMediaFeedPayload extends MusicianFeedPayload {
  const ProfileMediaFeedPayload({
    required this.mediaAssetId,
    required this.kind,
    required this.displayUrl,
    required this.playbackUrl,
    required this.thumbnailUrl,
    required this.title,
    required this.description,
    required this.durationSeconds,
    required this.width,
    required this.height,
  });

  final String mediaAssetId;
  final String kind;
  final String? displayUrl;
  final String? playbackUrl;
  final String? thumbnailUrl;
  final String? title;
  final String? description;
  final int? durationSeconds;
  final int? width;
  final int? height;

  factory ProfileMediaFeedPayload.fromJson(Object? json, String path) {
    final map = _object(json, path);
    return ProfileMediaFeedPayload(
      mediaAssetId: _requiredText(map['mediaAssetId'], '$path.mediaAssetId'),
      kind: _requiredText(map['kind'], '$path.kind').toUpperCase(),
      displayUrl: _optionalHttpUrl(map['displayUrl'], '$path.displayUrl'),
      playbackUrl: _optionalHttpUrl(map['playbackUrl'], '$path.playbackUrl'),
      thumbnailUrl: _optionalHttpUrl(map['thumbnailUrl'], '$path.thumbnailUrl'),
      title: _optionalText(map['title'], '$path.title'),
      description: _optionalText(map['description'], '$path.description'),
      durationSeconds: _optionalNonNegativeInt(
        map['durationSeconds'],
        '$path.durationSeconds',
      ),
      width: _optionalNonNegativeInt(map['width'], '$path.width'),
      height: _optionalNonNegativeInt(map['height'], '$path.height'),
    );
  }
}

class CollabFeedPayload extends MusicianFeedPayload {
  const CollabFeedPayload({required this.listing});
  final Map<String, dynamic> listing;

  factory CollabFeedPayload.fromJson(Object? json, String path) {
    final map = _object(json, path);
    return CollabFeedPayload(
      listing: UnmodifiableMapView(_object(map['listing'], '$path.listing')),
    );
  }
}

class EventFeedPayload extends MusicianFeedPayload {
  const EventFeedPayload({
    required this.event,
    required this.note,
    required this.publicationId,
  });

  final Map<String, dynamic> event;
  final String? note;
  final String? publicationId;

  factory EventFeedPayload.fromJson(Object? json, String path) {
    final map = _object(json, path);
    return EventFeedPayload(
      event: UnmodifiableMapView(_object(map['event'], '$path.event')),
      note: _optionalText(map['note'], '$path.note'),
      publicationId: _optionalText(map['publicationId'], '$path.publicationId'),
    );
  }
}

class ProfileShareFeedPayload extends MusicianFeedPayload {
  const ProfileShareFeedPayload({
    required this.shareId,
    required this.note,
    required this.publishedAt,
    required this.source,
  });

  final String shareId;
  final String? note;
  final DateTime publishedAt;
  final Map<String, dynamic> source;

  factory ProfileShareFeedPayload.fromJson(Object? json, String path) {
    final map = _object(json, path);
    return ProfileShareFeedPayload(
      shareId: _requiredText(map['shareId'], '$path.shareId'),
      note: _optionalText(map['note'], '$path.note'),
      publishedAt: _requiredDate(map['publishedAt'], '$path.publishedAt'),
      source: UnmodifiableMapView(_object(map['source'], '$path.source')),
    );
  }
}

class ActivityFeedPayload extends MusicianFeedPayload {
  const ActivityFeedPayload({
    required this.action,
    required this.actor,
    required this.targetItemType,
    required this.targetPayload,
  });

  final String action;
  final MusicianFeedActor actor;
  final MusicianFeedItemType targetItemType;
  final MusicianFeedPayload targetPayload;

  factory ActivityFeedPayload.fromJson(Object? json, String path) {
    final map = _object(json, path);
    final targetType = MusicianFeedItemType.parse(
      map['targetItemType'],
      '$path.targetItemType',
    );
    if (const {
      MusicianFeedItemType.activityFollow,
      MusicianFeedItemType.activityLike,
      MusicianFeedItemType.activityComment,
      MusicianFeedItemType.profileCompletion,
    }.contains(targetType)) {
      throw MusicianFeedFormatException(
        '$path.targetItemType cannot recursively contain activity/system items',
      );
    }
    return ActivityFeedPayload(
      action: _requiredText(map['action'], '$path.action').toUpperCase(),
      actor: MusicianFeedActor.fromJson(map['actor'], path: '$path.actor'),
      targetItemType: targetType,
      targetPayload: MusicianFeedPayload.parse(
        targetType,
        map['targetPayload'],
        '$path.targetPayload',
      ),
    );
  }
}

class CompletionFeedPayload extends MusicianFeedPayload {
  const CompletionFeedPayload({
    required this.completed,
    required this.total,
    required this.tasks,
  });

  final int completed;
  final int total;
  final List<MusicianFeedCompletionTask> tasks;

  factory CompletionFeedPayload.fromJson(Object? json, String path) {
    final map = _object(json, path);
    final rawTasks = map['tasks'];
    if (rawTasks is! List) {
      throw MusicianFeedFormatException('$path.tasks must be a list');
    }
    final completed = _requiredNonNegativeInt(
      map['completed'],
      '$path.completed',
    );
    final total = _requiredNonNegativeInt(map['total'], '$path.total');
    if (completed > total || rawTasks.length > total) {
      throw MusicianFeedFormatException(
        '$path contains inconsistent completion counts',
      );
    }
    return CompletionFeedPayload(
      completed: completed,
      total: total,
      tasks: List.unmodifiable(
        rawTasks.indexed.map(
          (entry) => MusicianFeedCompletionTask.fromJson(
            entry.$2,
            '$path.tasks[${entry.$1}]',
          ),
        ),
      ),
    );
  }
}

class MusicianFeedCompletionTask {
  const MusicianFeedCompletionTask({
    required this.code,
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.route,
    required this.priority,
    required this.complete,
  });

  final String code;
  final String title;
  final String description;
  final String ctaLabel;
  final String route;
  final int priority;
  final bool complete;

  factory MusicianFeedCompletionTask.fromJson(Object? json, String path) {
    final map = _object(json, path);
    return MusicianFeedCompletionTask(
      code: _requiredText(map['code'], '$path.code').toUpperCase(),
      title: _requiredText(map['title'], '$path.title'),
      description: _requiredText(map['description'], '$path.description'),
      ctaLabel: _requiredText(map['ctaLabel'], '$path.ctaLabel'),
      route: _requiredText(map['route'], '$path.route'),
      priority: _requiredNonNegativeInt(map['priority'], '$path.priority'),
      complete: _requiredBool(map['complete'], '$path.complete'),
    );
  }
}

class SponsoredFeedPayload extends MusicianFeedPayload {
  const SponsoredFeedPayload({
    required this.title,
    required this.body,
    required this.mediaUrl,
    required this.ctaLabel,
    required this.ctaUrl,
  });

  final String title;
  final String body;
  final String? mediaUrl;
  final String ctaLabel;
  final String ctaUrl;

  factory SponsoredFeedPayload.fromJson(Object? json, String path) {
    final map = _object(json, path);
    return SponsoredFeedPayload(
      title: _requiredText(map['title'], '$path.title'),
      body: _requiredText(map['body'], '$path.body'),
      mediaUrl: _optionalHttpUrl(map['mediaUrl'], '$path.mediaUrl'),
      ctaLabel: _requiredText(map['ctaLabel'], '$path.ctaLabel'),
      ctaUrl: _requiredNavigationTarget(map['ctaUrl'], '$path.ctaUrl'),
    );
  }
}

class MusicianFeedFormatException implements FormatException {
  const MusicianFeedFormatException(this.message);

  @override
  final String message;

  @override
  dynamic get source => null;

  @override
  int? get offset => null;

  @override
  String toString() => 'MusicianFeedFormatException: $message';
}

Map<String, dynamic> _object(Object? value, String path) {
  if (value is! Map) {
    throw MusicianFeedFormatException('$path must be an object');
  }
  try {
    return value.cast<String, dynamic>();
  } on TypeError {
    throw MusicianFeedFormatException('$path must use string keys');
  }
}

String _requiredText(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    throw MusicianFeedFormatException('$path must be non-empty text');
  }
  return value.trim();
}

String _requiredBoundedText(
  Object? value,
  String path, {
  required int maximumLength,
}) {
  final parsed = _requiredText(value, path);
  if (parsed.length > maximumLength) {
    throw MusicianFeedFormatException(
      '$path must be at most $maximumLength characters',
    );
  }
  return parsed;
}

String? _optionalText(Object? value, String path) {
  if (value == null) return null;
  if (value is! String) {
    throw MusicianFeedFormatException('$path must be text or null');
  }
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Object? value, String path) {
  if (value is! num || !value.isFinite || value != value.roundToDouble()) {
    throw MusicianFeedFormatException('$path must be an integer');
  }
  return value.toInt();
}

int _requiredNonNegativeInt(Object? value, String path) {
  final parsed = _requiredInt(value, path);
  if (parsed < 0) {
    throw MusicianFeedFormatException('$path must be non-negative');
  }
  return parsed;
}

int? _optionalNonNegativeInt(Object? value, String path) {
  if (value == null) return null;
  return _requiredNonNegativeInt(value, path);
}

bool _requiredBool(Object? value, String path) {
  if (value is! bool) {
    throw MusicianFeedFormatException('$path must be a boolean');
  }
  return value;
}

DateTime _requiredDate(Object? value, String path) {
  final text = _requiredText(value, path);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !parsed.isUtc) {
    throw MusicianFeedFormatException('$path must be an ISO-8601 UTC instant');
  }
  return parsed;
}

String _requiredNavigationTarget(Object? value, String path) {
  final parsed = _optionalNavigationTarget(value, path);
  if (parsed == null) {
    throw MusicianFeedFormatException(
      '$path must be an HTTPS URL or an internal route',
    );
  }
  return parsed;
}

String? _optionalNavigationTarget(Object? value, String path) {
  final text = _optionalText(value, path);
  if (text == null) return null;
  if (text.startsWith('/') &&
      !text.startsWith('//') &&
      !text.contains('\\') &&
      !text.contains(RegExp(r'[\u0000-\u001F\u007F]'))) {
    final uri = Uri.tryParse(text);
    if (uri != null &&
        uri.scheme.isEmpty &&
        uri.host.isEmpty &&
        uri.path.startsWith('/')) {
      return uri.toString();
    }
  }
  return _optionalHttpUrl(text, path);
}

String? _optionalHttpUrl(Object? value, String path) {
  final text = _optionalText(value, path);
  if (text == null) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw MusicianFeedFormatException('$path must be an HTTPS URL or null');
  }
  return uri.toString();
}
