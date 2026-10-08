import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/diagnostics/crash_reporting.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../data/system_health_repository.dart';
import '../../domain/system_health.dart';
import '../widgets/admin_visual_theme.dart';

class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({
    super.key,
    required this.repository,
    required this.sessions,
  });
  final SystemHealthRepository repository;
  final AuthSessionManager sessions;

  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends State<SystemHealthScreen>
    with WidgetsBindingObserver {
  SystemHealthSnapshot? _snapshot;
  List<MobileDiagnosticSummary>? _recentEvents;
  String? _recentError;
  String? _error;
  bool _loading = false;
  bool _foreground = true;
  bool _checkingReport = false;
  Stopwatch _age = Stopwatch();
  final Stopwatch _lastAttempt = Stopwatch();
  Timer? _timer;
  int _generation = 0;

  bool get _allowed => canViewSystemHealth(widget.sessions.session);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    widget.sessions.addListener(_sessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !_foreground ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      setState(() {}); // Measurement age advances even when requests fail.
      final refresh = _snapshot?.refreshIntervalSeconds ?? 15;
      if (!_lastAttempt.isRunning ||
          _lastAttempt.elapsed.inSeconds >= refresh) {
        _refresh();
      }
    });
  }

  void _sessionChanged() {
    _generation++;
    _age.stop();
    if (!mounted) return;
    setState(() {
      _snapshot = null;
      _recentEvents = null;
      _recentError = null;
      _error = null;
      _loading = false;
    });
    if (_allowed) _refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted ||
        _loading ||
        !_allowed ||
        !_foreground ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final generation = _generation;
    // Include transport and the parallel recent-events wait in the age. A slow
    // response must not make an already old measurement appear fresh again.
    final measurementAge = Stopwatch()..start();
    _lastAttempt
      ..reset()
      ..start();
    setState(() => _loading = true);
    final snapshotFuture = widget.repository.load();
    final recentFuture = widget.repository.loadRecentEvents();
    final result = await snapshotFuture;
    final recent = await recentFuture;
    if (!mounted || generation != _generation || !_allowed) {
      measurementAge.stop();
      return;
    }
    setState(() {
      _loading = false;
      _error = result.error?.message;
      _recentError = recent.isSuccess
          ? null
          : 'Son hata listesi güncellenemedi; gösterilen kayıtlar eski olabilir.';
      if (recent.isSuccess) _recentEvents = recent.data;
      if (result.isSuccess) {
        _snapshot = result.data;
        _age.stop();
        _age = measurementAge;
      } else {
        measurementAge.stop();
      }
    });
  }

  Future<void> _checkReport() async {
    if (!_allowed || _checkingReport) return;
    final session = widget.sessions.session;
    setState(() => _checkingReport = true);
    final accepted = await CrashReporting.reportAcceptanceCheck();
    if (!mounted) return;
    setState(() => _checkingReport = false);
    if (!identical(session, widget.sessions.session) || !_allowed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted
              ? 'Deneme hata raporu sunucuda kaydedildi.'
              : 'Raporun kaydı doğrulanamadı. Bir dakika sonra tekrar deneyebilirsin.',
        ),
      ),
    );
    if (accepted) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _age.stop();
    _lastAttempt.stop();
    widget.sessions.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AdminThemeScope(
    child: Builder(
      builder: (context) {
        final snapshot = _snapshot;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Sistem sağlığı'),
            actions: [
              IconButton(
                key: const Key('health-refresh'),
                tooltip: 'Yenile',
                onPressed: _allowed && !_loading ? _refresh : null,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: !_allowed
                ? const Center(
                    child: Text(
                      'Sistem sağlığını görmek için yönetim yetkisi gerekli.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AdminSectionCard(
                        title: 'Hizmetlerin durumu',
                        icon: Icons.monitor_heart_outlined,
                        description:
                            'Son ölçümler ve kullanıcıya yansıyan etkileri.',
                        children: [
                          _StatusPill(
                            status:
                                snapshot?.effectiveStatus(_age.elapsed) ??
                                HealthStatus.unknown,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            snapshot == null
                                ? 'İlk ölçüm bekleniyor.'
                                : 'Son güncelleme: ${DateFormat('dd.MM.yyyy HH:mm:ss').format(snapshot.generatedAt.toLocal())}',
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Ölçüm yok veya ölçüm eski, hizmetin sağlıklı olduğu anlamına gelmez.',
                          ),
                        ],
                      ),
                      if (_loading)
                        const LinearProgressIndicator(
                          key: Key('health-loading'),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_error!, key: const Key('health-error')),
                        ),
                      ValueListenableBuilder<CrashReportingStatus>(
                        valueListenable: CrashReporting.status,
                        builder: (context, status, _) => Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AdminSectionCard(
                            title: 'Bu uygulamanın hata raporlaması',
                            icon: Icons.bug_report_outlined,
                            description: switch (status) {
                              CrashReportingStatus.ready =>
                                'Hata raporlaması yapılandırıldı. Teslim, sunucudaki kayıtla doğrulanır.',
                              CrashReportingStatus.disabled =>
                                'Bu uygulama paketinde hata raporlaması kapalı.',
                              CrashReportingStatus.unavailable =>
                                'Hata raporlaması başlatılamadı.',
                            },
                            children: [
                              if (status == CrashReportingStatus.ready &&
                                  CrashReporting.environment != 'production')
                                AdminBrandButton(
                                  key: const Key('health-diagnostic-check'),
                                  label: _checkingReport
                                      ? 'Kontrol ediliyor…'
                                      : 'Deneme raporu gönder',
                                  icon: Icons.fact_check_outlined,
                                  onPressed: _checkingReport
                                      ? null
                                      : _checkReport,
                                ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AdminSectionCard(
                          title: 'Son mobil hata kayıtları',
                          icon: Icons.history_rounded,
                          description:
                              'Sunucunun aldığı en son 10 rapor. Hesap ve mesaj içeriği içermez.',
                          children: [
                            if (_recentError != null)
                              Text(
                                _recentError!,
                                key: const Key('health-recent-error'),
                              ),
                            if (_recentEvents == null && _recentError == null)
                              const Text('Kayıtlar bekleniyor.'),
                            if (_recentEvents?.isEmpty == true)
                              const Text(
                                'Henüz rapor yok. Bu, tüm cihazların sorunsuz olduğunu göstermez.',
                              ),
                            for (final event
                                in _recentEvents ??
                                    const <MobileDiagnosticSummary>[])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${MobileDiagnosticSummary.errorLabels[event.errorType]} · ${event.severity == 'FATAL' ? 'Ciddi' : 'Hata'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormat('dd.MM.yyyy HH:mm:ss').format(event.receivedAt.toLocal())} · ${MobileDiagnosticSummary.sourceLabels[event.source]} · ${MobileDiagnosticSummary.environmentLabels[event.environment]}',
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      for (final component
                          in snapshot?.components ?? const <HealthComponent>[])
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: AdminSectionCard(
                            title: component.label,
                            icon: Icons.insights_outlined,
                            description: component.userImpact,
                            children: [
                              _StatusPill(
                                status: component.effectiveStatus(
                                  _age.elapsed,
                                  snapshot!.staleAfterSeconds,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                component.measuredAt == null
                                    ? 'Henüz doğrulanmış ölçüm yok.'
                                    : 'Ölçüm: ${DateFormat('dd.MM.yyyy HH:mm:ss').format(component.measuredAt!.toLocal())}',
                              ),
                              if (component.metrics.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final metric
                                        in component.metrics.entries)
                                      Chip(
                                        label: Text(
                                          '${healthMetricLabels[metric.key]}: ${_number(metric.value)}',
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      const Text(
                        'Bu ekran yalnızca durum gösterir; iş veya bildirimleri yeniden göndermez.',
                      ),
                    ],
                  ),
          ),
        );
      },
    ),
  );

  String _number(double value) => NumberFormat(
    value == value.roundToDouble() ? '#,##0' : '#,##0.0',
    'tr_TR',
  ).format(value);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final HealthStatus status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      HealthStatus.up => const Color(0xff3A976F),
      HealthStatus.down => AppColors.coral,
      HealthStatus.degraded || HealthStatus.stale => const Color(0xffB1761C),
      _ => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Semantics(
      label: 'Durum: ${status.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == HealthStatus.up
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              status.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
