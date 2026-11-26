import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../data/admin_user_directory_repository.dart';
import '../../domain/admin_analytics_report.dart';
import '../../domain/admin_user_directory.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_statistics_trend.dart';
import '../widgets/admin_visual_theme.dart';

part 'admin_statistics_details.dart';

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];
final _decimal = NumberFormat('#,##0.#', 'tr');
String _fmt(num? value) => value == null ? '—' : _decimal.format(value);
DateTime _istanbul(DateTime value) =>
    value.toUtc().add(const Duration(hours: 3));
String _date(DateTime time) =>
    '${time.day} ${_months[time.month - 1]} ${time.year}';
String _clock(DateTime time) => DateFormat('HH:mm').format(time);
String _window(DateTime at) {
  final end = _istanbul(at);
  final start = end.subtract(const Duration(minutes: 5));
  return start.day == end.day
      ? '${_date(end)} · ${_clock(start)}–${_clock(end)} TSİ'
      : '${_date(start)} ${_clock(start)}–${_date(end)} ${_clock(end)} TSİ';
}

String _period(DateTime month, AdminAnalyticsReport? report) {
  final endOfMonth = DateTime.utc(month.year, month.month + 1, 0);
  final asOf = report == null ? null : _istanbul(report.asOf);
  final last = asOf != null && reportMonth(asOf) == reportMonth(month)
      ? asOf.day
      : endOfMonth.day;
  final coverage = report?.coverageStart;
  final first = coverage != null && reportMonth(coverage) == reportMonth(month)
      ? coverage.day
      : 1;
  if (first == last) {
    return '${_date(DateTime.utc(month.year, month.month, first))} · Türkiye saati';
  }
  return '$first–$last ${_months[month.month - 1]} ${month.year} · Türkiye saati';
}

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({
    super.key,
    required this.repository,
    required this.sessions,
    required this.entry,
    this.frame,
  });
  final AdminUserDirectoryRepository repository;
  final AuthSessionManager sessions;
  final AuthSession entry;
  final AdminSubpageFrame? frame;

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsState();
}

class _AdminStatisticsState extends State<AdminStatisticsScreen>
    with WidgetsBindingObserver {
  AdminUserProfileType? _profile;
  late DateTime _month;
  int? _day;
  Future<Result<AdminAnalyticsReport>>? _report;
  Future<Result<MemberPreferenceCounts>>? _counts;
  bool _loading = false;
  bool _accessRevoked = false;
  Timer? _timer;

  bool get _allowed =>
      !_accessRevoked &&
      identical(widget.sessions.session, widget.entry) &&
      canReadAdminUsers(widget.entry);

  @override
  void initState() {
    super.initState();
    final now = _istanbul(DateTime.now());
    _month = DateTime.utc(now.year, now.month);
    WidgetsBinding.instance.addObserver(this);
    if (_allowed) _request();
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshVisible(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshVisible();
  }

  void _refreshVisible() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!mounted ||
        !_allowed ||
        _loading ||
        ModalRoute.of(context)?.isCurrent != true ||
        (lifecycle != null && lifecycle != AppLifecycleState.resumed)) {
      return;
    }
    setState(_request);
  }

  void _request({bool counts = true}) {
    final request = widget.repository.analyticsReport(_month, _profile);
    _report = request;
    _loading = true;
    request.then((result) {
      _checkAccess(result);
      if (identical(_report, request)) _loading = false;
    });
    if (counts) {
      _counts = widget.repository.preferenceCounts(_profile);
      _counts!.then(_checkAccess);
    }
  }

  void _checkAccess(Result<Object?> result) {
    if (mounted && !_accessRevoked && isAdminUsersAccessError(result.error)) {
      setState(() => _accessRevoked = true);
    }
  }

  void _reload() {
    if (_allowed) setState(_request);
  }

  void _selectDay(int? day) => setState(() => _day = day == 0 ? null : day);

  void _setMonth(DateTime month) {
    if (!_allowed || month == _month) return;
    setState(() {
      _month = month;
      _day = null;
      _request(counts: false);
    });
  }

  Future<void> _chooseMonth(String value) async {
    final now = _istanbul(DateTime.now());
    if (value == 'other') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _month,
        initialDatePickerMode: DatePickerMode.year,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year, now.month + 1, 0),
        helpText: 'Rapor ayından bir gün seç',
        confirmText: 'Seç',
        cancelText: 'Vazgeç',
      );
      if (mounted && picked != null) {
        _setMonth(DateTime.utc(picked.year, picked.month));
      }
    } else {
      _setMonth(DateTime.parse('$value-01T00:00:00Z'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: widget.sessions,
      builder: (context, _) {
        if (!_allowed) {
          return const Center(child: Text('Yönetim yetkisi gerekli.'));
        }
        final theme = Theme.of(context);
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          children: [
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Sistem'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Text(
              'İstatistikler',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Üye profili'),
                DropdownButton<AdminUserProfileType?>(
                  value: _profile,
                  items: [
                    const DropdownMenuItem(child: Text('Tüm üyeler')),
                    for (final type in AdminUserProfileType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: (value) {
                    if (!_allowed) return;
                    setState(() {
                      _profile = value;
                      _request();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<Result<AdminAnalyticsReport>>(
              future: _report,
              key: ValueKey((reportMonth(_month), _profile)),
              builder: (context, snapshot) {
                final report = snapshot.data?.data;
                final loading =
                    snapshot.connectionState != ConnectionState.done;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (loading) const LinearProgressIndicator(),
                    if (!loading && report == null)
                      _Retry('İstatistikler alınamadı.', _reload),
                    _live(report?.live, report?.liveSource),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text('Aylık rapor', style: theme.textTheme.titleLarge),
                        _monthMenu(),
                      ],
                    ),
                    _Note(_period(_month, report)),
                    if (report?.coverageStart case final coverage?
                        when coverage.isAfter(_month))
                      _Note(
                        'Ölçüm kaydı ${_date(coverage)} tarihinde başladı.',
                      ),
                    if (report?.hasIssues == true)
                      const _Note('Bazı veriler henüz alınamadı.'),
                    const SizedBox(height: 16),
                    AdminStatisticsTrend(
                      days: _chartDays(report?.usage),
                      average: _fmt(report?.usage?.avgDau),
                      format: _fmt,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Metric(
                          _fmt(report?.membership?.newAccounts),
                          'Yeni üye\nSoundConnect',
                        ),
                        _Metric(
                          _fmt(report?.usage?.mau),
                          'Aylık aktif üye\nGA4',
                        ),
                        _Metric(
                          report?.usage?.activeMinutes == null
                              ? '—'
                              : '${_fmt(report!.usage!.activeMinutes)} dk',
                          'Aktif gün başına süre\nGA4 özeti',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Detail(
                      'Üyelik ve ölçüm tercihleri',
                      Icons.person_add_outlined,
                      [
                        ..._membershipDetails(
                          report?.membership,
                          _profile,
                          current:
                              report != null &&
                              reportMonth(_istanbul(report.asOf)) ==
                                  report.month,
                        ),
                        const _Sub('Üyelerin son ölçüm tercihi'),
                        FutureBuilder<Result<MemberPreferenceCounts>>(
                          future: _counts,
                          key: ValueKey(_profile),
                          builder: (context, snap) {
                            final counts = snap.data?.data;
                            if (counts == null) {
                              return snap.connectionState !=
                                      ConnectionState.done
                                  ? const LinearProgressIndicator()
                                  : _Retry(
                                      'Üye tercihleri alınamadı.',
                                      _reload,
                                    );
                            }
                            final at = _istanbul(counts.asOf);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Note(
                                  'SoundConnect · ${_date(at)} ${_clock(at)} TSİ',
                                ),
                                _Fact('Açık', _fmt(counts.granted)),
                                _Fact('Kapalıyı seçti', _fmt(counts.denied)),
                                _Fact('Henüz seçmedi', _fmt(counts.undecided)),
                                const _Note(
                                  'Tercihler kaydını tamamlamış üyelerin güncel kararını gösterir. Misafir tercihi cihazda saklanır.',
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    _Detail(
                      'Aktiflik ve yoğun saatler',
                      Icons.schedule_outlined,
                      _activityDetails(report?.usage),
                    ),
                    _Detail(
                      'Bölümlerde geçirilen süre',
                      Icons.view_list_outlined,
                      _sectionDetails(report?.usage),
                    ),
                    _Detail(
                      'İlk hafta ve geri dönüş',
                      Icons.track_changes_outlined,
                      _firstWeekDetails(report?.firstWeek, report?.usage),
                    ),
                    _Detail(
                      'Ayın beş dakikalık zirvesi',
                      Icons.timeline_outlined,
                      _peakDetails(report, _profile),
                    ),
                    const SizedBox(height: 10),
                    const _Note(
                      'Üyelik sayıları SoundConnect hesap kayıtlarından gelir. GA4 aylık kullanım raporları ölçüme izin verenleri kapsar. Misafir kurulumları her üye filtresinde ayrı gösterilir.',
                    ),
                    if (report != null)
                      _Note(
                        'Rapor güncellemesi · ${_date(_istanbul(report.asOf))} ${_clock(_istanbul(report.asOf))} TSİ',
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
    return widget.frame?.call(body) ??
        AdminThemeScope(
          child: Scaffold(body: SafeArea(child: body)),
        );
  }

  Map<DateTime, int?> _chartDays(ReportUsage? usage) {
    if (usage == null || usage.daily.isEmpty) return {};
    final last = DateTime.utc(_month.year, _month.month + 1, 0).day;
    return {
      for (var day = 1; day <= last; day++)
        DateTime.utc(_month.year, _month.month, day):
            usage.daily[DateTime.utc(_month.year, _month.month, day)],
    };
  }

  Widget _monthMenu() {
    final now = _istanbul(DateTime.now());
    final options = {
      for (var i = 0; i < 12; i++) DateTime.utc(now.year, now.month - i),
      _month,
    }.toList()..sort((a, b) => b.compareTo(a));
    return DropdownButton<String>(
      value: reportMonth(_month),
      hint: const Text('Rapor ayı'),
      items: [
        for (final date in options)
          DropdownMenuItem(
            value: reportMonth(date),
            child: Text('${_months[date.month - 1]} ${date.year}'),
          ),
        const DropdownMenuItem(value: 'other', child: Text('Başka ay seç…')),
      ],
      onChanged: (value) {
        if (value != null) _chooseMonth(value);
      },
    );
  }

  Widget _live(ReportLive? live, AnalyticsReportSource? source) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xff1a292e)
            : const Color(0xffe4f1ed),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? const Color(0xff3c5959)
              : const Color(0xffa6c7bc),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xff9adbc6)
                      : const Color(0xff29745e),
                ),
                const SizedBox(width: 8),
                Text('Son 5 dakikada aktif', style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                _Metric(
                  _fmt(live?.members),
                  _profile == null ? 'Üye' : '${_profile!.label} üye',
                ),
                _Metric(_fmt(live?.guests), 'Misafir kurulumu'),
              ],
            ),
            const SizedBox(height: 6),
            _Note(
              [
                if (source != null) source.label,
                live == null ? 'Canlı ölçüm bulunmuyor.' : _window(live.asOf),
              ].join(' · '),
            ),
          ],
        ),
      ),
    );
  }
}
