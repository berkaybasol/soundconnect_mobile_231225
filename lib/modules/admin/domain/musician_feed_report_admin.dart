import '../../../core/auth/auth_session.dart';

const musicianFeedReportAdminPermission = 'MANAGE_MUSICIAN_FEED_REPORTS';

bool canManageMusicianFeedReports(AuthSession session) =>
    session.isAuthenticated &&
    session.token?.trim().isNotEmpty == true &&
    session.isActive &&
    !session.requiresListenerProfileChoice &&
    session.userId?.trim().isNotEmpty == true &&
    session.permissions.contains(musicianFeedReportAdminPermission);

typedef MusicianFeedReportAdminIdentity = ({String userId, String token});

MusicianFeedReportAdminIdentity? musicianFeedReportAdminIdentity(
  AuthSession session,
) => canManageMusicianFeedReports(session)
    ? (userId: session.userId!.trim(), token: session.token!.trim())
    : null;

enum MusicianFeedReportStatus {
  fresh('NEW', 'Yeni'),
  reviewing('REVIEWING', 'İnceleniyor'),
  dismissed('DISMISSED', 'İşlem yapılmadı'),
  actioned('ACTIONED', 'Akıştan kaldırıldı'),
  restored('RESTORED', 'Karar geri alındı');

  const MusicianFeedReportStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static MusicianFeedReportStatus parse(Object? value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw const FormatException('Invalid report status'),
  );
}

enum MusicianFeedReportDecision {
  startReview('START_REVIEW', 'İncelemeye başla'),
  dismiss('DISMISS', 'İşlem yapmadan kapat'),
  removeFromFeed('REMOVE_FROM_FEED', 'Müzisyen akışından kaldır'),
  restoreToFeed('RESTORE_TO_FEED', 'Bu kaldırma kararını geri al');

  const MusicianFeedReportDecision(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static MusicianFeedReportDecision parse(Object? value) => values.firstWhere(
    (decision) => decision.apiValue == value,
    orElse: () => throw const FormatException('Invalid report decision'),
  );
}

const musicianFeedReportItemTypes = <String, String>{
  'TRACK': 'Parça',
  'PROFILE_MEDIA': 'Profil medyası',
  'COLLAB': 'İş birliği',
  'EVENT': 'Etkinlik',
  'EVENT_PROFILE_SHARE': 'Etkinlik paylaşımı',
  'OVERTHINKING_PROFILE_SHARE': 'Overthinking paylaşımı',
  'TABLEGROUP_PROFILE_SHARE': 'Masa paylaşımı',
  'PROFILE': 'Profil',
  'ACTIVITY_FOLLOW': 'Takip hareketi',
  'ACTIVITY_LIKE': 'Beğeni hareketi',
  'ACTIVITY_COMMENT': 'Yorum hareketi',
  'PROFILE_COMPLETION': 'Profil tamamlama',
  'SPONSORED': 'Sponsorlu içerik',
};

class MusicianFeedReportSummary {
  const MusicianFeedReportSummary({
    required this.id,
    required this.version,
    required this.status,
    required this.itemId,
    required this.itemType,
    required this.targetType,
    required this.targetId,
    required this.reportedAt,
    required this.title,
    this.reason,
    this.authorDisplayName,
  });

  final String id;
  final int version;
  final MusicianFeedReportStatus status;
  final String itemId;
  final String itemType;
  final String targetType;
  final String targetId;
  final DateTime reportedAt;
  final String title;
  final String? reason;
  final String? authorDisplayName;

  factory MusicianFeedReportSummary.fromJson(Object? value) {
    final json = _map(value);
    final version = json['version'];
    if (version is! int || version < 0) {
      throw const FormatException('Invalid report version');
    }
    return MusicianFeedReportSummary(
      id: _id(json['id']),
      version: version,
      status: MusicianFeedReportStatus.parse(json['status']),
      itemId: _text(json['itemId']),
      itemType: _text(json['itemType']),
      targetType: _text(json['targetType']),
      targetId: _id(json['targetId']),
      reportedAt: _date(json['reportedAt']),
      title: _optionalText(json['title']) ?? 'Akış içeriği',
      reason: _optionalText(json['reason']),
      authorDisplayName: _optionalText(json['authorDisplayName']),
    );
  }
}

class MusicianFeedReportAdminPage {
  const MusicianFeedReportAdminPage({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
  final List<MusicianFeedReportSummary> items;
  final String? nextCursor;
  final bool hasMore;

  factory MusicianFeedReportAdminPage.fromJson(Object? value) {
    final json = _map(value);
    final items = json['items'];
    final more = json['hasMore'];
    final cursor = _optionalText(json['nextCursor']);
    if (items is! List ||
        items.length > 50 ||
        more is! bool ||
        (more && cursor == null) ||
        (cursor != null && cursor.length > 1024)) {
      throw const FormatException('Invalid report page');
    }
    return MusicianFeedReportAdminPage(
      items: List.unmodifiable(items.map(MusicianFeedReportSummary.fromJson)),
      nextCursor: cursor,
      hasMore: more,
    );
  }
}

class MusicianFeedReportHistory {
  const MusicianFeedReportHistory({
    required this.id,
    required this.decision,
    required this.previousStatus,
    required this.status,
    required this.actorUserId,
    required this.occurredAt,
    required this.resolutionNote,
  });
  final String id;
  final MusicianFeedReportDecision decision;
  final MusicianFeedReportStatus previousStatus;
  final MusicianFeedReportStatus status;
  final String actorUserId;
  final DateTime occurredAt;
  final String resolutionNote;

  factory MusicianFeedReportHistory.fromJson(Object? value) {
    final json = _map(value);
    return MusicianFeedReportHistory(
      id: _id(json['id']),
      decision: MusicianFeedReportDecision.parse(json['decision']),
      previousStatus: MusicianFeedReportStatus.parse(json['previousStatus']),
      status: MusicianFeedReportStatus.parse(json['status']),
      actorUserId: _id(json['actorUserId']),
      occurredAt: _date(json['occurredAt']),
      resolutionNote: _text(json['resolutionNote']),
    );
  }
}

class MusicianFeedReportDetail {
  const MusicianFeedReportDetail({
    required this.report,
    required this.reporterUserId,
    required this.evidence,
    this.scopeDescription,
    required this.allowedDecisions,
    required this.activeRestriction,
    required this.history,
  });
  final MusicianFeedReportSummary report;
  final String reporterUserId;
  final Map<String, Object?> evidence;
  final String? scopeDescription;
  final List<MusicianFeedReportDecision> allowedDecisions;
  final bool activeRestriction;
  final List<MusicianFeedReportHistory> history;

  factory MusicianFeedReportDetail.fromJson(Object? value) {
    final json = _map(value);
    final decisions = json['allowedDecisions'];
    final history = json['history'];
    final restricted = json['activeRestriction'];
    if (decisions is! List || history is! List || restricted is! bool) {
      throw const FormatException('Invalid report detail');
    }
    return MusicianFeedReportDetail(
      report: MusicianFeedReportSummary.fromJson(json['report']),
      reporterUserId: _id(json['reporterUserId']),
      evidence: _freezeMap(_map(json['evidence'])),
      scopeDescription: _optionalText(json['scopeDescription']),
      allowedDecisions: List.unmodifiable(
        decisions.map(MusicianFeedReportDecision.parse).toSet(),
      ),
      activeRestriction: restricted,
      history: List.unmodifiable(
        history.map(MusicianFeedReportHistory.fromJson),
      ),
    );
  }
}

bool isMusicianFeedReportId(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);

class MusicianFeedOrphanRestriction {
  const MusicianFeedOrphanRestriction({
    required this.reportId,
    required this.scopeKey,
    required this.scopeDescription,
    required this.appliedByUserId,
    required this.appliedAt,
    required this.updatedAt,
  });
  final String reportId;
  final String scopeKey;
  final String scopeDescription;
  final String appliedByUserId;
  final DateTime appliedAt;
  final DateTime updatedAt;
  factory MusicianFeedOrphanRestriction.fromJson(Object? value) {
    final json = _map(value);
    return MusicianFeedOrphanRestriction(
      reportId: _id(json['reportId']),
      scopeKey: _text(json['scopeKey']),
      scopeDescription: _text(json['scopeDescription']),
      appliedByUserId: _id(json['appliedByUserId']),
      appliedAt: _date(json['appliedAt']),
      updatedAt: _date(json['updatedAt']),
    );
  }
}

class MusicianFeedOrphanRestrictionsPage {
  const MusicianFeedOrphanRestrictionsPage({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });
  final List<MusicianFeedOrphanRestriction> items;
  final String? nextCursor;
  final bool hasMore;
  factory MusicianFeedOrphanRestrictionsPage.fromJson(Object? value) {
    final json = _map(value);
    final items = json['items'];
    final more = json['hasMore'];
    final cursor = _optionalText(json['nextCursor']);
    if (items is! List ||
        items.length > 50 ||
        more is! bool ||
        (more && cursor == null) ||
        (cursor != null && cursor.length > 1024)) {
      throw const FormatException('Invalid restrictions page');
    }
    return MusicianFeedOrphanRestrictionsPage(
      items: List.unmodifiable(
        items.map(MusicianFeedOrphanRestriction.fromJson),
      ),
      nextCursor: cursor,
      hasMore: more,
    );
  }
}

class MusicianFeedRestrictionRestored {
  const MusicianFeedRestrictionRestored({
    required this.reportId,
    required this.updatedAt,
    required this.activeRestriction,
  });
  final String reportId;
  final DateTime updatedAt;
  final bool activeRestriction;
  factory MusicianFeedRestrictionRestored.fromJson(Object? value) {
    final json = _map(value);
    if (json['active'] != false || json['activeRestriction'] is! bool) {
      throw const FormatException('Invalid restriction decision');
    }
    return MusicianFeedRestrictionRestored(
      reportId: _id(json['reportId']),
      updatedAt: _date(json['updatedAt']),
      activeRestriction: json['activeRestriction'] as bool,
    );
  }
}

bool isValidMusicianFeedResolutionNote(String note) {
  final normalized = note.trim();
  return normalized.length >= 5 &&
      normalized.length <= 500 &&
      !normalized.runes.any(
        (rune) =>
            (rune < 32 && rune != 9 && rune != 10) ||
            (rune >= 127 && rune <= 159) ||
            (rune >= 0xd800 && rune <= 0xdfff),
      );
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected object');
  }
  return Map<String, Object?>.from(value);
}

Map<String, Object?> _freezeMap(Map<String, Object?> value) => Map.unmodifiable(
  value.map(
    (key, item) => MapEntry(
      key,
      item is Map
          ? _freezeMap(_map(item))
          : item is List
          ? List<Object?>.unmodifiable(
              item.map(
                (entry) => entry is Map ? _freezeMap(_map(entry)) : entry,
              ),
            )
          : item,
    ),
  ),
);

String _text(Object? value) {
  final text = _optionalText(value);
  if (text == null) throw const FormatException('Expected text');
  return text;
}

String? _optionalText(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Expected text');
  final text = value.trim();
  return text.isEmpty ? null : text;
}

String _id(Object? value) {
  final id = _text(value);
  if (!isMusicianFeedReportId(id)) {
    throw const FormatException('Invalid identifier');
  }
  return id;
}

DateTime _date(Object? value) {
  final date = value is String ? DateTime.tryParse(value) : null;
  if (date == null || !date.isUtc) {
    throw const FormatException('Invalid timestamp');
  }
  return date;
}
