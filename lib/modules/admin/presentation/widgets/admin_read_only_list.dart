import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../../studio/domain/entities/studio_page.dart';
import '../../data/admin_list_repository.dart';
import '../../domain/admin_panel_access.dart';
import 'admin_panel_frame.dart';
import 'application_review_widgets.dart';

class AdminReadOnlyList<T> extends StatefulWidget {
  const AdminReadOnlyList({
    super.key,
    required this.repository,
    required this.title,
    required this.itemLabel,
    required this.countLabel,
    required this.rowBuilder,
    this.rowKey,
    required this.sessions,
    required this.initialSession,
    this.frame,
  });

  final AdminListRepository<T> repository;
  final String title;
  final String itemLabel;
  final String countLabel;
  final Widget Function(T) rowBuilder;
  final Key Function(T)? rowKey;
  final AuthSessionManager sessions;
  final AuthSession initialSession;
  final AdminSubpageFrame? frame;

  @override
  State<AdminReadOnlyList<T>> createState() => _AdminReadOnlyListState<T>();
}

class _AdminReadOnlyListState<T> extends State<AdminReadOnlyList<T>> {
  Result<StudioPage<T>>? _result;
  bool _accessLost = false;
  bool _loading = false;
  int _page = 0;

  bool get _canRead =>
      !_accessLost &&
      identical(widget.sessions.session, widget.initialSession) &&
      widget.repository.canRead(widget.initialSession);

  @override
  void initState() {
    super.initState();
    widget.sessions.addListener(_sessionChanged);
    _load(0);
  }

  @override
  void dispose() {
    widget.sessions.removeListener(_sessionChanged);
    super.dispose();
  }

  void _sessionChanged() {
    if (!_canRead) _deny();
  }

  void _deny() {
    if (_accessLost) return;
    setState(() {
      _accessLost = true;
      _result = null;
    });
  }

  Future<void> _load(int page) async {
    if (!_canRead) {
      _deny();
      return;
    }
    if (_loading) return;
    setState(() {
      _loading = true;
      _page = page;
      _result = null;
    });
    final result = await widget.repository.list(page);
    if (!mounted || _accessLost) return;
    if (!_canRead ||
        isAdminPanelAccessError(result.error) ||
        result.error?.code == widget.repository.accessError.code) {
      _deny();
      return;
    }
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final data = result?.data;
    final ready = result != null && _canRead;
    return ApplicationPageFrame(
      frame: widget.frame,
      title: widget.title,
      backLabel: 'Başvurular',
      onRefresh: ready ? () => _load(0) : null,
      child: !_canRead
          ? Center(child: Text(widget.repository.accessError.message))
          : ListView(
              key: ValueKey(_page),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                if (widget.frame != null) ...[
                  Semantics(
                    header: true,
                    child: Text(
                      widget.title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -.9,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (result == null)
                  const Center(child: CircularProgressIndicator())
                else if (data == null) ...[
                  Text(widget.repository.listError.message),
                  TextButton(
                    onPressed: () => _load(_page),
                    child: const Text('Tekrar dene'),
                  ),
                ] else ...[
                  if (data.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        _page == 0
                            ? 'Henüz ${widget.itemLabel} yok.'
                            : 'Bu sayfada ${widget.itemLabel} yok.',
                      ),
                    )
                  else ...[
                    Text(
                      '${data.totalItems} ${widget.countLabel}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ApplicationSurface(
                      rows: [
                        for (final item in data.items)
                          Semantics(
                            key: widget.rowKey?.call(item),
                            container: true,
                            child: widget.rowBuilder(item),
                          ),
                      ],
                    ),
                  ],
                  if (_page > 0 || data.hasNext)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _page > 0 ? () => _load(_page - 1) : null,
                          child: const Text('Önceki sayfa'),
                        ),
                        TextButton(
                          onPressed:
                              data.hasNext &&
                                  _page < AdminListRepository.maxPage
                              ? () => _load(_page + 1)
                              : null,
                          child: const Text('Sonraki sayfa'),
                        ),
                      ],
                    ),
                ],
              ],
            ),
    );
  }
}
