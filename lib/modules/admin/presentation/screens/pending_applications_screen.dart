import 'package:flutter/material.dart' hide Page;
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../../../core/pagination/page.dart';
import '../../data/pending_application_repository.dart';
import '../../domain/pending_application.dart';
import '../widgets/admin_visual_theme.dart';

String _date(PendingApplication item) =>
    DateFormat('dd.MM.yyyy HH:mm').format(item.appliedAt.toLocal());

class PendingApplicationsScreen extends StatefulWidget {
  const PendingApplicationsScreen({
    super.key,
    required this.sessions,
    required this.repository,
  });
  final AuthSessionManager sessions;
  final PendingApplicationRepository repository;

  @override
  State<PendingApplicationsScreen> createState() => _PendingApplicationsState();
}

class _PendingApplicationsState extends State<PendingApplicationsScreen> {
  late final AuthSession _entry = widget.sessions.session;
  late ApplicationKind _kind;
  int _page = 0;
  late Future<Result<Page<PendingApplication>>> _result;

  @override
  void initState() {
    super.initState();
    _kind = ApplicationKind.values.firstWhere(
      (kind) => kind.canRead(_entry),
      orElse: () => ApplicationKind.venue,
    );
    _result = widget.repository.list(_entry, _kind, _page);
  }

  void _load(ApplicationKind kind, int page) {
    setState(() {
      _kind = kind;
      _page = page;
      _result = widget.repository.list(_entry, kind, page);
    });
  }

  Future<void> _open(PendingApplication item) async {
    if (!identical(_entry, widget.sessions.session) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ApplicationDetail(
          entry: _entry,
          kind: _kind,
          id: item.id,
          repository: widget.repository,
          sessions: widget.sessions,
        ),
      ),
    );
    if (mounted && identical(_entry, widget.sessions.session)) {
      _load(_kind, _page);
    }
  }

  @override
  Widget build(BuildContext context) => AdminThemeScope(
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Başvurular'),
        actions: [
          IconButton(
            tooltip: 'Listeyi yenile',
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(_kind, 0),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.sessions,
        builder: (context, _) {
          if (!identical(_entry, widget.sessions.session) ||
              !_kind.canRead(_entry)) {
            return const Center(
              child: Text('Başvuruları görme yetkin değişti.'),
            );
          }
          final kinds = ApplicationKind.values.where(
            (kind) => kind.canRead(_entry),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final kind in kinds)
                    ChoiceChip(
                      label: Text(kind.label),
                      selected: kind == _kind,
                      onSelected: (selected) {
                        if (selected && kind != _kind) _load(kind, 0);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'İnceleme bekleyenler',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _ReadResult<Page<PendingApplication>>(
                result: _result,
                retry: () => _load(_kind, _page),
                builder: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (data.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          _page == 0
                              ? 'Bekleyen ${_kind.label.toLowerCase()} başvurusu yok.'
                              : 'Bu sayfada bekleyen başvuru kalmadı.',
                        ),
                      ),
                    for (final item in data.items)
                      Card(
                        child: ListTile(
                          title: Text(item.businessName),
                          subtitle: Text(
                            [
                              item.location,
                              _date(item),
                            ].where((line) => line.isNotEmpty).join('\n'),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(item),
                        ),
                      ),
                    if (_page > 0 || data.hasNext)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _page == 0
                                ? null
                                : () => _load(_kind, _page - 1),
                            child: const Text('Önceki sayfa'),
                          ),
                          TextButton(
                            onPressed: data.hasNext
                                ? () => _load(_kind, _page + 1)
                                : null,
                            child: const Text('Sonraki sayfa'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _ApplicationDetail extends StatefulWidget {
  const _ApplicationDetail({
    required this.entry,
    required this.sessions,
    required this.kind,
    required this.id,
    required this.repository,
  });
  final AuthSession entry;
  final AuthSessionManager sessions;
  final ApplicationKind kind;
  final String id;
  final PendingApplicationRepository repository;

  @override
  State<_ApplicationDetail> createState() => _ApplicationDetailState();
}

class _ApplicationDetailState extends State<_ApplicationDetail> {
  Future<Result<PendingApplication>> _load() =>
      widget.repository.detail(widget.entry, widget.kind, widget.id);
  late Future<Result<PendingApplication>> _result = _load();

  @override
  Widget build(BuildContext context) => AdminThemeScope(
    child: Scaffold(
      appBar: AppBar(title: Text('${widget.kind.label} başvurusu')),
      body: ListenableBuilder(
        listenable: widget.sessions,
        builder: (context, _) {
          if (!identical(widget.entry, widget.sessions.session) ||
              !widget.kind.canRead(widget.entry)) {
            return const Center(
              child: Text('Başvuruları görme yetkin değişti.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _ReadResult<PendingApplication>(
                result: _result,
                retry: () => setState(() => _result = _load()),
                builder: (item) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.businessName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    for (final (label, value) in [
                      ('Durum', 'İnceleme bekliyor'),
                      ('Başvuran', item.applicantUsername),
                      ('Başvuru tarihi', _date(item)),
                      ('Konum', item.location),
                      ('Adres', item.address ?? ''),
                    ])
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(label),
                        subtitle: Text(value.isEmpty ? 'Belirtilmemiş' : value),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _ReadResult<T> extends StatelessWidget {
  const _ReadResult({
    required this.result,
    required this.retry,
    required this.builder,
  });
  final Future<Result<T>> result;
  final VoidCallback retry;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<Result<T>>(
    future: result,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        );
      }
      final read = snapshot.data;
      if (read != null && read.isSuccess) return builder(read.data as T);
      return Column(
        children: [
          Text(read?.error?.message ?? 'Başvuru bilgileri alınamadı.'),
          if (!const {
            'access_changed',
            'not_pending',
          }.contains(read?.error?.code))
            TextButton(onPressed: retry, child: const Text('Tekrar dene')),
        ],
      );
    },
  );
}
