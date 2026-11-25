import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../collab/domain/collab_page.dart';
import 'admin_panel_frame.dart';
import 'application_review_widgets.dart';

/// The panel's paged queue and its detail route share one session-bound access signal.
class AdminReportList<S extends Enum, F extends Enum, R>
    extends StatefulWidget {
  const AdminReportList({
    super.key,
    required this.sessions,
    this.initialSession,
    this.frame,
    required this.title,
    required this.statuses,
    required this.statusLabel,
    required this.filterTitle,
    required this.filters,
    required this.filterLabel,
    required this.load,
    required this.id,
    required this.rowTitle,
    required this.rowSubtitle,
    required this.canRead,
    required this.isAccessError,
    required this.accessMessage,
    required this.review,
  });
  final AuthSessionManager sessions;
  final AuthSession? initialSession;
  final AdminSubpageFrame? frame;
  final String title, filterTitle, accessMessage;
  final List<S> statuses;
  final List<F> filters;
  final String Function(S) statusLabel;
  final String Function(F) filterLabel;
  final String Function(R) id, rowTitle, rowSubtitle;
  final Future<Result<CollabPage<R>>> Function(S, F?, int) load;
  final bool Function(AuthSession) canRead;
  final bool Function(AppError?) isAccessError;
  final Widget Function(R, ValueListenable<bool>, VoidCallback) review;
  @override
  State<AdminReportList<S, F, R>> createState() =>
      _AdminReportListState<S, F, R>();
}

class _AdminReportListState<S extends Enum, F extends Enum, R>
    extends State<AdminReportList<S, F, R>> {
  late final _entry = widget.initialSession ?? widget.sessions.session;
  late final _access = ValueNotifier(_sessionMatches);
  late S _status = widget.statuses.first;
  F? _reason;
  int _page = 0;
  int _request = 0;
  Result<CollabPage<R>>? _result;

  bool get _sessionMatches =>
      identical(widget.sessions.session, _entry) && widget.canRead(_entry);

  @override
  void initState() {
    super.initState();
    widget.sessions.addListener(_sessionChanged);
    if (_access.value) _load(0);
  }

  void _sessionChanged() {
    if (!_sessionMatches) _deny();
  }

  void _deny() {
    if (!mounted || !_access.value) return;
    _access.value = false;
    _result = null;
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_sessionChanged);
    _access.dispose();
    super.dispose();
  }

  Future<void> _load(int page) async {
    if (!_access.value) return;
    final request = ++_request;
    setState(() {
      _page = page;
      _result = null;
    });
    final result = await widget.load(_status, _reason, page);
    if (!mounted || !_access.value) return;
    if (widget.isAccessError(result.error)) {
      _deny();
      return;
    }
    if (request != _request) return;
    final data = result.data;
    if (data != null && page > 0 && page >= data.totalPages) {
      return _load(data.totalPages > 0 ? data.totalPages - 1 : 0);
    }
    setState(() => _result = result);
  }

  Future<void> _open(R report) async {
    if (!_access.value || ModalRoute.of(context)?.isCurrent != true) return;
    final nextStatus = await Navigator.of(context).push<S>(
      MaterialPageRoute(builder: (_) => widget.review(report, _access, _deny)),
    );
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      if (nextStatus != null) {
        _status = nextStatus;
        _reason = null;
      }
      await _load(nextStatus == null ? _page : 0);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _access,
    builder: (context, allowed, _) {
      final result = _result;
      final data = result?.data;
      final ready = allowed && result != null;
      return ApplicationPageFrame(
        frame: widget.frame,
        title: widget.title,
        backLabel: 'Şikâyetler',
        onRefresh: ready ? () => _load(0) : null,
        child: allowed
            ? ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  if (widget.frame != null) ...[
                    Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  DropdownButtonFormField<S>(
                    key: ValueKey(_status),
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Şikâyet durumu',
                    ),
                    items: [
                      for (final status in widget.statuses)
                        DropdownMenuItem(
                          value: status,
                          child: Text(widget.statusLabel(status)),
                        ),
                    ],
                    onChanged: !ready
                        ? null
                        : (status) {
                            if (status == null || status == _status) return;
                            _status = status;
                            _load(0);
                          },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<F?>(
                    key: ValueKey(_reason),
                    initialValue: _reason,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: widget.filterTitle),
                    hint: const Text('Tümü'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tümü')),
                      for (final reason in widget.filters)
                        DropdownMenuItem(
                          value: reason,
                          child: Text(widget.filterLabel(reason)),
                        ),
                    ],
                    onChanged: !ready
                        ? null
                        : (reason) {
                            if (reason == _reason) return;
                            _reason = reason;
                            _load(0);
                          },
                  ),
                  const SizedBox(height: 20),
                  if (result == null)
                    const Center(child: CircularProgressIndicator())
                  else if (data == null) ...[
                    Text(result.error!.message),
                    TextButton(
                      onPressed: () => _load(_page),
                      child: const Text('Tekrar dene'),
                    ),
                  ] else ...[
                    if (data.items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Bu filtrelere uygun şikâyet bulunamadı.'),
                      )
                    else
                      ApplicationSurface(
                        rows: [
                          for (final report in data.items)
                            ListTile(
                              key: ValueKey(widget.id(report)),
                              title: Text(widget.rowTitle(report)),
                              subtitle: Text(widget.rowSubtitle(report)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _open(report),
                            ),
                        ],
                      ),
                  ],
                  if (ready && (_page > 0 || (data?.hasNext ?? false)))
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _page > 0 ? () => _load(_page - 1) : null,
                          child: const Text('Önceki sayfa'),
                        ),
                        TextButton(
                          onPressed: data?.hasNext == true
                              ? () => _load(_page + 1)
                              : null,
                          child: const Text('Sonraki sayfa'),
                        ),
                      ],
                    ),
                ],
              )
            : Center(child: Text(widget.accessMessage)),
      );
    },
  );
}
