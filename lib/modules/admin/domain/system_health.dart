import '../../../core/auth/auth_session.dart';

bool canViewSystemHealth(AuthSession session) =>
    session.isAuthenticated &&
    session.isActive &&
    session.sessionScope == null &&
    !session.requiresListenerProfileChoice &&
    session.userId?.isNotEmpty == true &&
    session.expiresAt?.isAfter(DateTime.now()) == true &&
    !session.hasAnyRole(const ['LISTENER', 'ROLE_LISTENER']) &&
    (session.permissions.contains('ADMIN_PANEL_ACCESS') ||
        session.hasAnyRole(const ['OWNER', 'ROLE_OWNER']));

enum HealthStatus {
  up('UP', 'Normal'),
  degraded('DEGRADED', 'Dikkat'),
  down('DOWN', 'Kesinti'),
  unknown('UNKNOWN', 'Ölçüm yok'),
  disabled('DISABLED', 'Kapalı'),
  stale('STALE', 'Ölçüm eski');

  const HealthStatus(this.wire, this.label);
  final String wire;
  final String label;

  static HealthStatus parse(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => HealthStatus.unknown,
  );
}

const healthMetricLabels = <String, String>{
  'pending': 'Bekleyen',
  'inFlight': 'İşlenen',
  'deadLetter': 'Başarısız işler',
  'failed': 'Başarısız işler',
  'suppressed': 'Gönderilmeyen',
  'retry': 'Tekrar bekleyen',
  'publishing': 'Yayımlanan',
  'review': 'İnceleme bekleyen',
  'stale': 'Geciken',
  'oldestPendingAgeSeconds': 'En eski iş (sn)',
  'readyMessages': 'Kuyrukta hazır',
  'requestCount': 'İstek',
  'serverErrorCount': 'Sunucu hatası',
  'serverErrorRatePercent': 'Hata oranı (%)',
  'meanLatencyMillis': 'Ortalama yanıt (ms)',
  'windowSeconds': 'Ölçüm aralığı (sn)',
  'eventsLast15Minutes': 'Son 15 dk hata',
  'fatalEventsLast15Minutes': 'Son 15 dk ciddi hata',
  'slowFramesLast15Minutes': 'Son 15 dk yavaş ekran raporu',
  'lastEventAgeSeconds': 'Son rapor yaşı (sn)',
  'consumers': 'Çalışan tüketici',
  'providerAccepted': 'Sağlayıcının kabul ettiği',
};

class MobileDiagnosticSummary {
  const MobileDiagnosticSummary({
    required this.eventId,
    required this.receivedAt,
    required this.severity,
    required this.source,
    required this.errorType,
    required this.environment,
  });
  final String eventId;
  final DateTime receivedAt;
  final String severity;
  final String source;
  final String errorType;
  final String environment;

  static const sourceLabels = <String, String>{
    'FLUTTER_FRAMEWORK': 'Arayüz',
    'UNHANDLED_ZONE': 'Uygulama',
    'PLATFORM_DISPATCHER': 'Uygulama motoru',
    'FRAME_TIMING': 'Ekran akıcılığı',
    'DIAGNOSTICS_CHECK': 'Deneme raporu',
    'BLOC': 'İşlem durumu',
    'RECOVERABLE': 'İşlem',
  };
  static const errorLabels = <String, String>{
    'ApplicationError': 'Uygulama hatası',
    'StateError': 'İşlem durumu hatası',
    'ArgumentError': 'Parametre hatası',
    'FormatException': 'Veri biçimi hatası',
    'TimeoutException': 'Zaman aşımı',
    'SocketException': 'Bağlantı hatası',
    'HttpException': 'Sunucu bağlantı hatası',
    'FirebaseException': 'Firebase hatası',
    'DioException': 'API bağlantı hatası',
    'FlutterError': 'Arayüz hatası',
    'RangeError': 'Veri sınırı hatası',
    'TypeError': 'Veri türü hatası',
    'NoSuchMethodError': 'İşlem çağrısı hatası',
    'ConcurrentModificationError': 'Eşzamanlı işlem hatası',
    'AssertionError': 'Uygulama denetimi hatası',
    'UnsupportedError': 'Desteklenmeyen işlem',
    'MissingPluginException': 'Cihaz bileşeni eksik',
    'PlatformException': 'Cihaz işlemi hatası',
    'FrameBudgetExceeded': 'Ekran akıcılığı düşük',
    'DiagnosticAcceptanceCheck': 'Deneme raporu',
  };
  static const environmentLabels = <String, String>{
    'local': 'Yerel',
    'staging': 'Test',
    'production': 'Üretim',
  };

  static List<MobileDiagnosticSummary> listFromJson(Object? raw) {
    final events = _map(raw)['events'];
    if (events is! List || events.length > 10) {
      throw const FormatException('Invalid event list');
    }
    final parsed = events.map((raw) {
      final map = _map(raw);
      final id = map['eventId'];
      if (id is! String ||
          !RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
          ).hasMatch(id) ||
          !const {'ERROR', 'FATAL'}.contains(map['severity']) ||
          !sourceLabels.containsKey(map['source']) ||
          !errorLabels.containsKey(map['errorType']) ||
          !environmentLabels.containsKey(map['environment'])) {
        throw const FormatException('Invalid diagnostic summary');
      }
      return MobileDiagnosticSummary(
        eventId: id,
        receivedAt: _timestamp(map['receivedAt']),
        severity: map['severity'] as String,
        source: map['source'] as String,
        errorType: map['errorType'] as String,
        environment: map['environment'] as String,
      );
    }).toList();
    if (parsed.map((event) => event.eventId).toSet().length != parsed.length) {
      throw const FormatException('Duplicate diagnostic summary');
    }
    return List.unmodifiable(parsed);
  }
}

class HealthComponent {
  const HealthComponent({
    required this.id,
    required this.label,
    required this.status,
    required this.measuredAt,
    required this.ageSeconds,
    required this.userImpact,
    required this.metrics,
  });

  final String id;
  final String label;
  final HealthStatus status;
  final DateTime? measuredAt;
  final int? ageSeconds;
  final String userImpact;
  final Map<String, double> metrics;

  factory HealthComponent.fromJson(Object? raw) {
    final map = _map(raw);
    final metrics = _map(map['metrics']);
    if (metrics.length > 32) throw const FormatException('Too many metrics');
    final values = <String, double>{};
    for (final entry in metrics.entries) {
      if (!healthMetricLabels.containsKey(entry.key)) continue;
      if (entry.value is! num ||
          !(entry.value as num).isFinite ||
          (entry.value as num) < 0) {
        throw const FormatException('Invalid measurement');
      }
      values[entry.key] = (entry.value as num).toDouble();
    }
    final measuredAt = map['measuredAt'] == null
        ? null
        : _timestamp(map['measuredAt']);
    final age = map['ageSeconds'];
    if (age != null && (age is! int || age < 0)) {
      throw const FormatException('Invalid measurement age');
    }
    final status = HealthStatus.parse(map['status']);
    return HealthComponent(
      id: _text(map['id'], 64),
      label: _text(map['label'], 100),
      status: measuredAt == null && status != HealthStatus.disabled
          ? HealthStatus.unknown
          : status,
      measuredAt: measuredAt,
      ageSeconds: age as int?,
      userImpact: _text(map['userImpact'], 500),
      metrics: Map.unmodifiable(values),
    );
  }

  HealthStatus effectiveStatus(Duration elapsed, int staleAfterSeconds) {
    if (status == HealthStatus.disabled || status == HealthStatus.unknown) {
      return status;
    }
    if (measuredAt == null || ageSeconds == null) return HealthStatus.unknown;
    return ageSeconds! + elapsed.inSeconds > staleAfterSeconds
        ? HealthStatus.stale
        : status;
  }
}

class SystemHealthSnapshot {
  const SystemHealthSnapshot({
    required this.status,
    required this.generatedAt,
    required this.refreshIntervalSeconds,
    required this.staleAfterSeconds,
    required this.components,
  });
  final HealthStatus status;
  final DateTime generatedAt;
  final int refreshIntervalSeconds;
  final int staleAfterSeconds;
  final List<HealthComponent> components;

  HealthStatus effectiveStatus(Duration elapsed) {
    if (elapsed.inSeconds > staleAfterSeconds) return HealthStatus.stale;
    final statuses = {
      status,
      for (final component in components)
        component.effectiveStatus(elapsed, staleAfterSeconds),
    };
    // Preserve the server's adverse observation while also aging each card.
    // A recent response never makes an old or missing measurement healthy.
    for (final candidate in const [
      HealthStatus.down,
      HealthStatus.degraded,
      HealthStatus.stale,
      HealthStatus.unknown,
      HealthStatus.up,
    ]) {
      if (statuses.contains(candidate)) return candidate;
    }
    return HealthStatus.disabled;
  }

  factory SystemHealthSnapshot.fromJson(Object? raw) {
    final map = _map(raw);
    final items = map['components'];
    final refresh = map['refreshIntervalSeconds'];
    final stale = map['staleAfterSeconds'];
    if (items is! List ||
        items.isEmpty ||
        items.length > 32 ||
        refresh is! int ||
        refresh < 5 ||
        refresh > 300 ||
        stale is! int ||
        stale < refresh ||
        stale > 3600) {
      throw const FormatException('Invalid health snapshot');
    }
    final components = items.map(HealthComponent.fromJson).toList();
    if (components.map((v) => v.id).toSet().length != components.length) {
      throw const FormatException('Duplicate component');
    }
    return SystemHealthSnapshot(
      status: HealthStatus.parse(map['status']),
      generatedAt: _timestamp(map['generatedAt']),
      refreshIntervalSeconds: refresh,
      staleAfterSeconds: stale,
      components: List.unmodifiable(components),
    );
  }
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is! Map || raw.keys.any((key) => key is! String)) {
    throw const FormatException('Invalid health data');
  }
  return Map<String, dynamic>.from(raw);
}

String _text(Object? raw, int max) {
  if (raw is! String ||
      raw.trim().isEmpty ||
      raw.length > max ||
      raw.contains(RegExp(r'[\x00-\x08\x0b-\x1f]'))) {
    throw const FormatException('Invalid health text');
  }
  return raw;
}

DateTime _timestamp(Object? raw) {
  if (raw is! String ||
      raw.length > 40 ||
      !RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(raw)) {
    throw const FormatException('Invalid health timestamp');
  }
  return DateTime.parse(raw).toUtc();
}
