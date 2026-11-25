import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../data/table_group_report_repository.dart';
import '../../domain/table_group_expiry_policy.dart';
import '../../domain/table_group_report.dart';
import '../widgets/table_group_report_sheet.dart';

class RecentTableReportScreen extends StatefulWidget {
  const RecentTableReportScreen({
    super.key,
    required this.repository,
    required this.actor,
  });
  final TableGroupReportRepository repository;
  final ApiRequestContext actor;

  @override
  State<RecentTableReportScreen> createState() =>
      _RecentTableReportScreenState();
}

class _RecentTableReportScreenState extends State<RecentTableReportScreen> {
  final _tables = <RecentReportableTable>[];
  int _nextPage = 0;
  bool _hasNext = true;
  bool _loading = false;
  String? _error;
  Timer? _expiryRefresh;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _expiryRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || !widget.repository.isCurrent(widget.actor)) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) _nextPage = 0;
    });
    final result = await widget.repository.recent(
      actor: widget.actor,
      page: _nextPage,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = result.error?.message;
      if (result.data case final data?) {
        if (reset || _nextPage == 0) _tables.clear();
        final known = _tables.map((table) => table.tableGroupId).toSet();
        _tables.addAll(
          data.items.where((table) => known.add(table.tableGroupId)),
        );
        _nextPage++;
        _hasNext = data.hasNext;
      }
    });
    _scheduleExpiry();
  }

  void _scheduleExpiry() {
    _expiryRefresh?.cancel();
    final now = DateTime.now();
    _tables.removeWhere((item) => !item.reportUntil.isAfter(now));
    if (_tables.isEmpty) return;
    final firstExpiry = _tables
        .map((item) => item.reportUntil)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final toExpiry = firstExpiry.difference(now);
    const minute = Duration(minutes: 1);
    _expiryRefresh = Timer(toExpiry < minute ? toExpiry : minute, () {
      if (mounted) setState(_scheduleExpiry);
    });
  }

  String _remaining(DateTime until) {
    final minutes = (until.difference(DateTime.now()).inSeconds / 60)
        .ceil()
        .clamp(0, 48 * 60);
    final hours = minutes ~/ 60;
    return hours == 0
        ? '$minutes dk. kaldı'
        : '$hours sa. ${minutes % 60} dk. kaldı';
  }

  String _context(RecentReportableTable table) => [
    if (table.location != null) table.location!,
    if (table.meetingAt != null) formatTableGroupMeetingAt(table.meetingAt),
  ].join(' · ');

  void _open(RecentReportableTable table) {
    if (!widget.repository.isCurrent(widget.actor)) return;
    if (!table.reportUntil.isAfter(DateTime.now())) {
      setState(_scheduleExpiry);
      return;
    }
    showTableGroupReportSheet(
      context,
      repository: widget.repository,
      actor: widget.actor,
      tableId: table.tableGroupId,
      kind: TableGroupReportKind.incident,
      evidenceLabel: 'Olayın geçtiği masa',
      evidenceText: table.title,
      evidenceContext: _context(table),
    );
  }

  @override
  Widget build(BuildContext context) => AppSurfaceThemeScope(
    child: Scaffold(
      appBar: AppBar(title: const Text('Yakın zamandaki masalar')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.repository.sessions,
          builder: (context, _) {
            if (!widget.repository.isCurrent(widget.actor)) {
              return Center(
                child: Text(TableGroupReportRepository.sessionChanged.message),
              );
            }
            return RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Hangi masada yaşandı?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Katılımın sona erdikten sonra 48 saat içinde olayı bildirebilirsin.',
                  ),
                  const SizedBox(height: 16),
                  for (final table in _tables)
                    Card(
                      child: ListTile(
                        title: Text(table.title),
                        subtitle: Text(
                          [
                            _context(table),
                            '${table.endLabel} · ${_remaining(table.reportUntil)}',
                          ].where((v) => v.isNotEmpty).join('\n'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(table),
                      ),
                    ),
                  if (_loading)
                    const Center(child: CircularProgressIndicator())
                  else if (_error != null) ...[
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Tekrar dene'),
                    ),
                  ] else ...[
                    if (_tables.isEmpty)
                      const Text(
                        'Son 48 saatte bildirim yapabileceğin masa bulunmuyor.',
                      ),
                    if (_hasNext)
                      TextButton(
                        onPressed: _load,
                        child: const Text('Daha fazla göster'),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}
