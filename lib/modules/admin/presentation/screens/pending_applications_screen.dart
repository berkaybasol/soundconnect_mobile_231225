import 'package:flutter/material.dart' hide Page;
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../../../core/pagination/page.dart';
import '../../data/pending_application_repository.dart';
import '../../domain/pending_application.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/application_review_widgets.dart';
import 'application_review_screen.dart';

String _date(PendingApplication item) =>
    DateFormat('dd.MM.yyyy HH:mm').format(item.appliedAt.toLocal());

class PendingApplicationsScreen extends StatefulWidget {
  const PendingApplicationsScreen({
    super.key,
    required this.sessions,
    required this.repository,
    this.initialKind,
    this.initialSession,
    this.frame,
  });
  final AuthSessionManager sessions;
  final PendingApplicationRepository repository;
  final ApplicationKind? initialKind;
  final AuthSession? initialSession;
  final AdminSubpageFrame? frame;

  @override
  State<PendingApplicationsScreen> createState() => _PendingApplicationsState();
}

class _PendingApplicationsState extends State<PendingApplicationsScreen> {
  late final AuthSession _entry =
      widget.initialSession ?? widget.sessions.session;
  late ApplicationKind _kind;
  int _page = 0;
  late Future<Result<Page<PendingApplication>>> _result;

  @override
  void initState() {
    super.initState();
    _kind =
        widget.initialKind ??
        ApplicationKind.values.firstWhere(
          (kind) => kind.canRead(_entry),
          orElse: () => ApplicationKind.venue,
        );
    _result = widget.repository.list(_entry, _kind, _page);
  }

  void _load(ApplicationKind kind, int page) {
    if (!identical(_entry, widget.sessions.session) || !kind.canRead(_entry)) {
      return;
    }
    setState(() {
      _kind = kind;
      _page = page;
      _result = widget.repository.list(_entry, kind, page);
    });
  }

  Future<void> _open(PendingApplication item) async {
    if (!identical(_entry, widget.sessions.session) ||
        !_kind.canRead(_entry) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ApplicationReviewScreen(
          frame: widget.frame,
          entry: _entry,
          kind: _kind,
          id: item.id,
          repository: widget.repository,
          sessions: widget.sessions,
        ),
      ),
    );
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      _load(_kind, _page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: widget.sessions,
      builder: (context, _) {
        if (!identical(_entry, widget.sessions.session) ||
            !_kind.canRead(_entry)) {
          return const Center(child: Text('Başvuruları görme yetkin değişti.'));
        }
        final kinds = ApplicationKind.values.where(
          (kind) => kind.canRead(_entry),
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          children: [
            if (widget.initialKind == null)
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
            if (widget.initialKind != null)
              Semantics(
                header: true,
                child: Text(
                  '${_kind.label} başvuruları',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.9,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'İnceleme bekleyenler',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
                  if (data.items.isNotEmpty)
                    ApplicationSurface(
                      rows: [
                        for (final item in data.items)
                          _ApplicationListRow(
                            item: item,
                            kind: _kind,
                            onTap: () => _open(item),
                          ),
                      ],
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
    );
    return ApplicationPageFrame(
      title: 'Başvurular',
      backLabel: 'Başvurular',
      frame: widget.frame,
      onRefresh: () => _load(_kind, 0),
      child: body,
    );
  }
}

class _ApplicationListRow extends StatelessWidget {
  const _ApplicationListRow({
    required this.item,
    required this.kind,
    required this.onTap,
  });
  final PendingApplication item;
  final ApplicationKind kind;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final venue = kind == ApplicationKind.venue;
    final dark = theme.brightness == Brightness.dark;
    final accent = venue
        ? (dark ? const Color(0xffff9a91) : const Color(0xff93423d))
        : (dark ? const Color(0xffbeadff) : const Color(0xff694c92));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      horizontalTitleGap: 12,
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox.square(
          dimension: 38,
          child: Icon(
            venue ? Icons.storefront_outlined : Icons.tune,
            size: 20,
            color: accent,
          ),
        ),
      ),
      title: Text(
        item.businessName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        [
          item.location,
          _date(item),
        ].where((text) => text.isNotEmpty).join(' · '),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
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
