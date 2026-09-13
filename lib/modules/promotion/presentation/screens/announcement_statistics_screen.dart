import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../shared/widgets/soundconnect_date_picker.dart';
import '../../../analytics/presentation/widgets/venue_analytics_reporting.dart';
import '../../../musician_feed/presentation/musician_feed_visual_theme.dart';
import '../../domain/announcement_access.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/entities/announcement_statistics.dart';
import '../../domain/promotion_repository.dart';

class AnnouncementStatisticsScreen extends StatefulWidget {
  const AnnouncementStatisticsScreen({
    super.key,
    required this.id,
    required this.repository,
    required this.sessions,
  });
  final String id;
  final PromotionRepository repository;
  final AuthSessionManager sessions;
  @override
  State<AnnouncementStatisticsScreen> createState() =>
      _AnnouncementStatisticsScreenState();
}

class _AnnouncementStatisticsScreenState
    extends State<AnnouncementStatisticsScreen> {
  late final AnnouncementSessionIdentity? _identity;
  late DateTime _to = _istanbulToday();
  late DateTime _from = _to.subtract(const Duration(days: 29));
  String? _source;
  String? _profile;
  AnnouncementStatistics? _data;
  String? _error;
  bool _loading = true;
  bool _revoked = false;
  int _epoch = 0;
  bool get _current =>
      mounted &&
      !_revoked &&
      _identity != null &&
      _identity ==
          announcementSessionIdentity(widget.sessions.session, admin: true);
  static DateTime _istanbulToday() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 3));
    return DateTime(now.year, now.month, now.day);
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  @override
  void initState() {
    super.initState();
    _identity = announcementSessionIdentity(
      widget.sessions.session,
      admin: true,
    );
    widget.sessions.addListener(_sessionChanged);
    unawaited(_load());
  }

  void _sessionChanged() {
    if (_identity !=
        announcementSessionIdentity(widget.sessions.session, admin: true)) {
      _revoked = true;
      _epoch++;
      if (mounted) {
        setState(() {
          _data = null;
          _loading = false;
          _error = 'Duyuru yönetim yetkin değişti.';
        });
      }
    }
  }

  Future<void> _load() async {
    if (!_current) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Duyuru yönetim yetkisi gerekli.';
        });
      }
      return;
    }
    final epoch = ++_epoch;
    setState(() {
      _loading = true;
      _data = null;
      _error = null;
    });
    final result = await widget.repository.announcementStatistics(
      widget.id,
      from: _date(_from),
      to: _date(_to),
      profileType: _profile,
      source: _source,
    );
    if (!_current || epoch != _epoch) return;
    setState(() {
      _loading = false;
      _data = result.data;
      _error = result.error?.message;
    });
  }

  Future<void> _pick(bool start) async {
    final value = await showSoundConnectDatePicker(
      context: context,
      initialDate: start ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: _istanbulToday(),
      helpText: start ? 'İlk gün' : 'Son gün',
    );
    if (!_current || value == null) return;
    final from = start ? value : _from;
    final to = start ? _to : value;
    if (to.isBefore(from) || to.difference(from).inDays > 365) {
      setState(() => _error = 'Tarih aralığı 1–366 gün olmalı.');
      return;
    }
    setState(() {
      _from = from;
      _to = to;
    });
    await _load();
  }

  @override
  void dispose() {
    _epoch++;
    widget.sessions.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MusicianFeedThemeScope(
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Duyuru istatistikleri')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Saat dilimi: Europe/Istanbul'),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _current ? () => _pick(true) : null,
                  child: Text(_date(_from)),
                ),
                OutlinedButton(
                  onPressed: _current ? () => _pick(false) : null,
                  child: Text(_date(_to)),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              initialValue: _source,
              decoration: const InputDecoration(labelText: 'Kaynak'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tüm kaynaklar')),
                DropdownMenuItem(value: 'FEED', child: Text('Akış')),
                DropdownMenuItem(
                  value: 'DIRECTORY',
                  child: Text('Duyuru listesi'),
                ),
              ],
              onChanged: !_current
                  ? null
                  : (value) {
                      setState(() => _source = value);
                      unawaited(_load());
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _profile,
              decoration: const InputDecoration(labelText: 'Profil'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Tüm profiller'),
                ),
                for (final role in announcementTargetProfiles)
                  DropdownMenuItem(
                    value: role,
                    child: Text(announcementProfileLabel(role)),
                  ),
              ],
              onChanged: !_current
                  ? null
                  : (value) {
                      setState(() => _profile = value);
                      unawaited(_load());
                    },
            ),
            const SizedBox(height: 20),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Column(
                children: [
                  Text(_error!),
                  if (_current)
                    TextButton(
                      onPressed: _load,
                      child: const Text('Yeniden dene'),
                    ),
                ],
              ),
            if (_data case final data?) ...[
              Text(
                'Güncelleme: ${data.updatedAt.toUtc().add(const Duration(hours: 3)).toIso8601String().substring(0, 19).replaceAll('T', ' ')}',
              ),
              const SizedBox(height: 12),
              AnalyticsReportSurface(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 20,
                  children: [
                    for (final metric
                        in AnnouncementStatistics.metricLabels.entries)
                      SizedBox(
                        width: 138,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              analyticsNumber(data.metrics[metric.key]!),
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(metric.value),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tekil erişim, seçili aralık ve filtreler için tekilleştirilir; günlük değerlerin toplamı değildir. Beğeni, yorum ve gizleyen sayıları seçili dönemde oluşmuş, hâlen mevcut kayıtlardır. Kaynağı belirlenemeyen eski etkileşimler yalnızca tüm kaynaklarda yer alır.',
              ),
              const SizedBox(height: 20),
              const Text('Günlük dağılım'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: [
                    const DataColumn(label: Text('Tarih')),
                    for (final metric
                        in AnnouncementStatistics.metricLabels.values)
                      DataColumn(label: Text(metric), numeric: true),
                  ],
                  rows: [
                    for (final day in data.daily)
                      DataRow(
                        cells: [
                          DataCell(Text(day.date)),
                          for (final metric
                              in AnnouncementStatistics.metricLabels.keys)
                            DataCell(
                              Text(analyticsNumber(day.metrics[metric]!)),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
