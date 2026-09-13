const announcementTargetProfiles = <String>[
  'MUSICIAN',
  'LISTENER',
  'VENUE',
  'STUDIO',
];

String announcementProfileLabel(String role) => switch (role) {
  'MUSICIAN' => 'Müzisyen',
  'LISTENER' => 'Dinleyici',
  'VENUE' => 'Mekân',
  'STUDIO' => 'Stüdyo',
  _ => role,
};

enum AnnouncementStatus {
  draft('DRAFT', 'Taslak'),
  scheduled('SCHEDULED', 'Planlandı'),
  published('PUBLISHED', 'Yayında'),
  ended('ENDED', 'Sona erdi'),
  archived('ARCHIVED', 'Arşivlendi');

  const AnnouncementStatus(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

/// An ANNOUNCEMENT projection of the existing Promotion aggregate.
/// Private media URLs are deliberately excluded; resolve them at display time.
class Announcement {
  const Announcement({
    required this.id,
    required this.version,
    required this.title,
    required this.body,
    required this.targetProfiles,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.startsAt,
    this.endsAt,
    this.firstPublishedAt,
    this.media,
    this.engagement = const AnnouncementEngagement(),
    this.feedHidden = false,
  });

  final String id;
  final int version;
  final String title;
  final String body;
  final Set<String> targetProfiles;
  final AnnouncementStatus status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? firstPublishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final AnnouncementMedia? media;
  final AnnouncementEngagement engagement;
  final bool feedHidden;

  factory Announcement.fromJson(Object? value) {
    final json = announcementObject(value);
    final targets = json['targetProfiles'];
    if (targets is! List ||
        targets.isEmpty ||
        targets.any((value) => !announcementTargetProfiles.contains(value))) {
      throw const FormatException('Invalid announcement audience');
    }
    final status = AnnouncementStatus.values
        .where((value) => value.wireValue == json['status'])
        .firstOrNull;
    if (status == null) {
      throw const FormatException('Invalid announcement status');
    }
    final hidden = json['feedHidden'] ?? false;
    if (hidden is! bool) {
      throw const FormatException('Invalid announcement hide state');
    }
    return Announcement(
      id: announcementId(json['id']),
      version: announcementCount(json['version']),
      title: announcementText(json['title'], 150),
      body: announcementText(json['body'], 5000),
      targetProfiles: Set.unmodifiable(targets.cast<String>()),
      status: status,
      startsAt: announcementDate(json['startsAt']),
      endsAt: announcementDate(json['endsAt']),
      firstPublishedAt: announcementDate(json['firstPublishedAt']),
      createdAt:
          announcementDate(json['createdAt']) ??
          (throw const FormatException('Missing announcement creation date')),
      updatedAt:
          announcementDate(json['updatedAt']) ??
          (throw const FormatException('Missing announcement update date')),
      media: json['media'] == null
          ? null
          : AnnouncementMedia.fromJson(json['media']),
      engagement: AnnouncementEngagement.fromJson(json['engagement']),
      feedHidden: hidden,
    );
  }
}

class AnnouncementMedia {
  const AnnouncementMedia({
    required this.assetId,
    required this.kind,
    required this.status,
    this.streamingProtocol,
    this.width,
    this.height,
    this.durationSeconds,
  });
  final String assetId;
  final String kind;
  final String status;
  final String? streamingProtocol;
  final int? width;
  final int? height;
  final int? durationSeconds;
  bool get isVideo => kind == 'VIDEO';
  double get aspectRatio =>
      (width ?? 0) > 0 && (height ?? 0) > 0 ? width! / height! : 16 / 9;

  factory AnnouncementMedia.fromJson(Object? value) {
    final json = announcementObject(value);
    final kind = json['kind'];
    if (kind != 'IMAGE' && kind != 'VIDEO') {
      throw const FormatException('Unsupported announcement media');
    }
    return AnnouncementMedia(
      assetId: announcementId(json['assetId']),
      kind: kind as String,
      status: announcementText(json['status'], 40),
      streamingProtocol: json['streamingProtocol'] as String?,
      width: json['width'] == null ? null : announcementCount(json['width']),
      height: json['height'] == null ? null : announcementCount(json['height']),
      durationSeconds: json['durationSeconds'] == null
          ? null
          : announcementCount(json['durationSeconds']),
    );
  }
}

class AnnouncementEngagement {
  const AnnouncementEngagement({
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  factory AnnouncementEngagement.fromJson(Object? value) {
    if (value == null) return const AnnouncementEngagement();
    final json = announcementObject(value);
    final liked = json['likedByMe'];
    if (liked is! bool) {
      throw const FormatException('Invalid announcement liked state');
    }
    return AnnouncementEngagement(
      likeCount: announcementCount(json['likeCount']),
      commentCount: announcementCount(json['commentCount']),
      likedByMe: liked,
    );
  }
}

class AnnouncementPage {
  const AnnouncementPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });
  final List<Announcement> items;
  final bool hasMore;
  final String? nextCursor;
  factory AnnouncementPage.fromJson(Object? value) {
    final json = announcementObject(value);
    final items = json['items'];
    final more = json['hasMore'];
    final cursor = json['nextCursor'];
    if (items is! List ||
        more is! bool ||
        (cursor != null &&
            (cursor is! String ||
                cursor.trim().isEmpty ||
                cursor.length > 4096)) ||
        (more && (cursor == null || items.isEmpty)) ||
        (!more && cursor != null)) {
      throw const FormatException('Invalid announcement pagination');
    }
    final parsed = items.map(Announcement.fromJson).toList(growable: false);
    if (parsed.map((item) => item.id).toSet().length != parsed.length) {
      throw const FormatException('Duplicate announcement');
    }
    return AnnouncementPage(
      items: List.unmodifiable(parsed),
      hasMore: more,
      nextCursor: cursor as String?,
    );
  }
}

class AnnouncementWrite {
  const AnnouncementWrite({
    required this.title,
    required this.body,
    required this.targetProfiles,
    this.mediaAssetId,
  });
  final String title;
  final String body;
  final Set<String> targetProfiles;
  final String? mediaAssetId;
  bool get isValid =>
      title.trim().isNotEmpty &&
      title.trim().length <= 150 &&
      body.trim().isNotEmpty &&
      body.trim().length <= 5000 &&
      targetProfiles.isNotEmpty &&
      targetProfiles.every(announcementTargetProfiles.contains) &&
      (mediaAssetId == null || isAnnouncementId(mediaAssetId!));
  Map<String, Object?> toJson({int? expectedVersion}) => {
    'title': title.trim(),
    'body': body.trim(),
    'targetProfiles': targetProfiles.toList()..sort(),
    'mediaAssetId': mediaAssetId,
    if (expectedVersion != null) 'expectedVersion': expectedVersion,
  };
}

bool isAnnouncementId(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
).hasMatch(value);
String announcementId(Object? value) {
  if (value is! String || !isAnnouncementId(value)) {
    throw const FormatException('Invalid announcement identity');
  }
  return value;
}

Map<String, dynamic> announcementObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid announcement object');
  }
  return value;
}

String announcementText(Object? value, int maximum) {
  if (value is! String || value.trim().isEmpty || value.length > maximum) {
    throw const FormatException('Invalid announcement text');
  }
  return value;
}

int announcementCount(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid announcement count');
  }
  return value;
}

DateTime? announcementDate(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Invalid announcement date');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw const FormatException('Announcement date requires timezone');
  }
  return parsed.toUtc();
}
