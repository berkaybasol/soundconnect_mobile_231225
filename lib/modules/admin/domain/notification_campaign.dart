import '../../../core/auth/auth_session.dart';

const campaignProfileLabels = <String, String>{
  'MUSICIAN': 'Müzisyen',
  'LISTENER': 'Dinleyici',
  'VENUE': 'Mekân',
  'STUDIO': 'Stüdyo',
};
const campaignTargetLabels = <String, String>{
  'HOME': 'Ana sayfa',
  'EVENTS': 'Etkinlikler',
  'PROFILE': 'Bir profil',
  'EVENT': 'Bir etkinlik',
  'CONTENT': 'Bir içerik',
  'TABLES': 'Masalar',
  'COLLAB': 'İş birlikleri',
  'MARKETPLACE': 'Pazar',
};
const campaignRepeatLabels = <String, String>{
  'ONCE': 'Bir kez',
  'DAILY': 'Her gün',
  'WEEKLY': 'Haftanın seçili günleri',
  'INTERVAL': 'Belirli gün aralıklarıyla',
};
const campaignStatusLabels = <String, String>{
  'DRAFT': 'Taslak',
  'SCHEDULED': 'Planlandı',
  'PAUSED': 'Duraklatıldı',
  'COMPLETED': 'Tamamlandı',
  'CANCELLED': 'İptal edildi',
};
const campaignZoneLabels = <String, String>{
  'Europe/Istanbul': 'Türkiye · İstanbul',
  'Etc/UTC': 'UTC',
  'Europe/Berlin': 'Almanya · Berlin',
  'Europe/London': 'Birleşik Krallık · Londra',
  'America/New_York': 'ABD · New York',
};

bool canManageNotificationCampaigns(AuthSession session) =>
    session.isAuthenticated &&
    session.isActive &&
    session.sessionScope == null &&
    !session.requiresListenerProfileChoice &&
    session.userId?.trim().isNotEmpty == true &&
    session.token?.trim().isNotEmpty == true &&
    session.expiresAt?.isAfter(DateTime.now()) == true &&
    !session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) &&
    session.hasAnyRole(const ['ADMIN', 'ROLE_ADMIN', 'OWNER', 'ROLE_OWNER']);

bool isCampaignId(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);

Map<String, dynamic> campaignMap(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Invalid campaign object');
  }
  return Map<String, dynamic>.from(value);
}

String _text(Object? value, {int max = 500}) {
  if (value is! String || value.trim().isEmpty || value.length > max) {
    throw const FormatException('Invalid campaign text');
  }
  return value;
}

int _integer(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Invalid campaign number');
  }
  return value;
}

String _choice(Object? value, Iterable<String> choices) {
  if (value is! String || !choices.contains(value)) {
    throw const FormatException('Invalid campaign choice');
  }
  return value;
}

DateTime? campaignInstant(Object? value) {
  if (value == null) return null;
  if (value is! String || !RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)) {
    throw const FormatException('Campaign instant requires timezone');
  }
  return DateTime.parse(value).toUtc();
}

/// Calendar fields in the selected IANA zone; never converted by device time.
DateTime campaignWallTime(String value) {
  if (!RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d(:\d\d(\.\d+)?)?$').hasMatch(value)) {
    throw const FormatException('Invalid local campaign date');
  }
  final result = DateTime.parse('${value}Z');
  if (campaignLocalIso(result).substring(0, 16) != value.substring(0, 16)) {
    throw const FormatException('Invalid local campaign calendar date');
  }
  return result;
}

String campaignLocalIso(DateTime value) => DateTime.utc(
  value.year,
  value.month,
  value.day,
  value.hour,
  value.minute,
  value.second,
  value.millisecond,
  value.microsecond,
).toIso8601String().replaceFirst(RegExp(r'(\.000)?Z$'), '');

String campaignDateLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String campaignCleanText(String value) =>
    value.trim().replaceAll(RegExp(r'[\r\n\t]'), ' ');

class CampaignLookup {
  const CampaignLookup({required this.id, required this.label, this.subtitle});
  final String id, label;
  final String? subtitle;
  factory CampaignLookup.fromJson(Object? value) {
    final json = campaignMap(value);
    final id = _text(json['id'], max: 36);
    if (!isCampaignId(id)) {
      throw const FormatException('Invalid lookup identity');
    }
    final username = json['username'];
    final label = json['label'] ?? json['displayName'] ?? username;
    return CampaignLookup(
      id: id,
      label: _text(label),
      subtitle: username is String
          ? '@$username${json['profileType'] is String ? ' · ${campaignProfileLabels[json['profileType']] ?? json['profileType']}' : ''}'
          : null,
    );
  }
}

class CampaignInput {
  const CampaignInput({
    required this.title,
    required this.message,
    required this.audienceMode,
    required this.profileTypes,
    required this.userIds,
    required this.targetKind,
    this.targetId,
    required this.localStartsAt,
    required this.zoneId,
    required this.repeat,
    this.intervalDays,
    this.weekDays = const [],
    this.localEndsAt,
    this.maxOccurrences,
  });
  final String title, message, audienceMode, targetKind, zoneId, repeat;
  final List<String> profileTypes, userIds;
  final String? targetId;
  final DateTime localStartsAt;
  final DateTime? localEndsAt;
  final int? intervalDays, maxOccurrences;
  final List<int> weekDays;
  bool get needsTarget =>
      const {'PROFILE', 'EVENT', 'CONTENT'}.contains(targetKind);

  String? get validationError {
    if (title.trim().isEmpty || title.trim().length > 120) {
      return 'Başlık 1–120 karakter olmalı.';
    }
    if (message.trim().isEmpty || message.trim().length > 500) {
      return 'Bildirim metni 1–500 karakter olmalı.';
    }
    if (RegExp(
      r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
    ).hasMatch('$title$message')) {
      return 'Metinde geçersiz karakter var.';
    }
    if (!const {'ALL', 'PROFILE_TYPES', 'USERS'}.contains(audienceMode)) {
      return 'Alıcıları seç.';
    }
    if (audienceMode == 'PROFILE_TYPES' &&
        (profileTypes.isEmpty ||
            profileTypes.any((p) => !campaignProfileLabels.containsKey(p)))) {
      return 'En az bir profil türü seç.';
    }
    if (audienceMode == 'USERS' &&
        (userIds.isEmpty ||
            userIds.length > 100 ||
            userIds.any((id) => !isCampaignId(id)))) {
      return '1–100 kullanıcı seç.';
    }
    if (!campaignTargetLabels.containsKey(targetKind) ||
        (needsTarget && (targetId == null || !isCampaignId(targetId!)))) {
      return 'Bildirimin açacağı hedefi seç.';
    }
    if (!campaignRepeatLabels.containsKey(repeat)) {
      return 'Tekrar düzenini seç.';
    }
    if (zoneId.trim().isEmpty || zoneId.length > 100) {
      return 'Saat dilimini seç.';
    }
    if (repeat == 'INTERVAL' &&
        (intervalDays == null || intervalDays! < 1 || intervalDays! > 365)) {
      return 'Gün aralığı 1–365 olmalı.';
    }
    if (repeat == 'WEEKLY' &&
        (weekDays.isEmpty || weekDays.any((d) => d < 1 || d > 7))) {
      return 'En az bir gün seç.';
    }
    if (localEndsAt != null && !localEndsAt!.isAfter(localStartsAt)) {
      return 'Bitiş zamanı başlangıçtan sonra olmalı.';
    }
    if (maxOccurrences != null &&
        (maxOccurrences! < 1 || maxOccurrences! > 10000)) {
      return 'Gönderim sayısı 1–10.000 olmalı.';
    }
    if (repeat != 'ONCE' && localEndsAt == null && maxOccurrences == null) {
      return 'Tekrarlar için bitiş tarihi veya gönderim sayısı belirle.';
    }
    return null;
  }

  Map<String, dynamic> toJson({int? expectedVersion}) => {
    if (expectedVersion != null) 'expectedVersion': expectedVersion,
    'title': campaignCleanText(title),
    'message': campaignCleanText(message),
    'audience': {
      'mode': audienceMode,
      'profileTypes': audienceMode == 'PROFILE_TYPES'
          ? profileTypes
          : <String>[],
      'userIds': audienceMode == 'USERS' ? userIds : <String>[],
    },
    'target': {'kind': targetKind, if (needsTarget) 'targetId': targetId},
    'schedule': {
      'localStartsAt': campaignLocalIso(localStartsAt),
      'zoneId': zoneId,
      'repeat': repeat,
      if (repeat == 'INTERVAL') 'intervalDays': intervalDays,
      'weekDays': repeat == 'WEEKLY' ? weekDays : <int>[],
      if (localEndsAt != null) 'localEndsAt': campaignLocalIso(localEndsAt!),
      if (repeat != 'ONCE' && maxOccurrences != null)
        'maxOccurrences': maxOccurrences,
    },
  };
}

class NotificationCampaign {
  const NotificationCampaign({
    required this.id,
    required this.version,
    required this.input,
    required this.status,
    required this.startsAt,
    required this.createdAt,
    required this.updatedAt,
    required this.stats,
    this.nextRunAt,
    this.selectedUsers = const [],
    this.targetLabel,
  });
  final String id, status;
  final int version;
  final CampaignInput input;
  final DateTime startsAt, createdAt, updatedAt;
  final DateTime? nextRunAt;
  final Map<String, int> stats;
  final List<CampaignLookup> selectedUsers;
  final String? targetLabel;
  bool get editable => status == 'DRAFT';
  factory NotificationCampaign.fromJson(Object? value) {
    final json = campaignMap(value);
    final audience = campaignMap(json['audience']);
    final target = campaignMap(json['target']);
    final schedule = campaignMap(json['schedule']);
    final stats = campaignMap(json['stats']);
    final id = _text(json['id'], max: 36);
    if (!isCampaignId(id)) {
      throw const FormatException('Invalid campaign identity');
    }
    final start = campaignInstant(schedule['startsAt']);
    if (start == null) throw const FormatException('Missing campaign start');
    final input = CampaignInput(
      title: _text(json['title'], max: 120),
      message: _text(json['message']),
      audienceMode: _choice(audience['mode'], const [
        'ALL',
        'PROFILE_TYPES',
        'USERS',
      ]),
      profileTypes: List<String>.unmodifiable(
        (audience['profileTypes'] as List).cast<String>(),
      ),
      userIds: List<String>.unmodifiable(
        (audience['userIds'] as List).cast<String>(),
      ),
      targetKind: _choice(target['kind'], campaignTargetLabels.keys),
      targetId: target['targetId'] as String?,
      localStartsAt: campaignWallTime(schedule['localStartsAt'] as String),
      localEndsAt: schedule['localEndsAt'] == null
          ? null
          : campaignWallTime(schedule['localEndsAt'] as String),
      zoneId: _text(schedule['zoneId'], max: 100),
      repeat: _choice(schedule['repeat'], campaignRepeatLabels.keys),
      intervalDays: schedule['intervalDays'] as int?,
      weekDays: List<int>.unmodifiable(
        (schedule['weekDays'] as List? ?? []).cast<int>(),
      ),
      maxOccurrences: schedule['maxOccurrences'] as int?,
    );
    if (input.validationError != null) {
      throw const FormatException('Invalid campaign definition');
    }
    return NotificationCampaign(
      id: id,
      version: _integer(json['version']),
      input: input,
      status: _choice(json['status'], campaignStatusLabels.keys),
      startsAt: start,
      nextRunAt: campaignInstant(json['nextRunAt']),
      createdAt: campaignInstant(json['createdAt'])!,
      updatedAt: campaignInstant(json['updatedAt'])!,
      stats: Map.unmodifiable({
        for (final key in const [
          'occurrences',
          'recipients',
          'notifications',
          'skipped',
        ])
          key: _integer(stats[key]),
      }),
      selectedUsers: List.unmodifiable(
        ((audience['users'] ?? json['selectedUsers']) as List? ?? []).map(
          CampaignLookup.fromJson,
        ),
      ),
      targetLabel:
          target['label'] as String? ??
          (json['selectedTarget'] is Map
              ? json['selectedTarget']['label'] as String?
              : null),
    );
  }
}

class CampaignPage {
  const CampaignPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });
  final List<NotificationCampaign> items;
  final int page, size, total;
  bool get hasMore => (page + 1) * size < total;
  factory CampaignPage.fromJson(Object? value) {
    final json = campaignMap(value);
    final items = (json['items'] as List)
        .map(NotificationCampaign.fromJson)
        .toList();
    final size = _integer(json['size']);
    if (size < 1 ||
        size > 50 ||
        items.length > size ||
        items.map((v) => v.id).toSet().length != items.length) {
      throw const FormatException('Invalid campaign page');
    }
    return CampaignPage(
      items: List.unmodifiable(items),
      page: _integer(json['page']),
      size: size,
      total: _integer(json['total']),
    );
  }
}
