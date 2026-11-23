import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../../collab/domain/collab_page.dart';
import '../../../collab/domain/collab_types.dart';
import '../../../collab/presentation/widgets/collab_management_widgets.dart';
import '../../data/collab_report_admin_repository.dart';
import '../../domain/collab_report_admin.dart';
import '../../domain/collab_report_admin_access.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/application_review_widgets.dart';
import 'collab_report_review_screen.dart';

class CollabReportAdminScreen extends StatefulWidget {
  const CollabReportAdminScreen({
    super.key,
    required this.sessions,
    required this.repository,
    this.initialSession,
    this.frame,
  });

  final AuthSessionManager sessions;
  final AuthSession? initialSession;
  final CollabReportAdminRepository repository;
  final AdminSubpageFrame? frame;

  @override
  State<CollabReportAdminScreen> createState() => _CollabReportAdminState();
}

class _CollabReportAdminState extends State<CollabReportAdminScreen> {
  late final _entry = widget.initialSession ?? widget.sessions.session;
  late final _access = ValueNotifier(_sessionMatches);
  CollabReportStatus _status = CollabReportStatus.open;
  CollabReportReason? _reason;
  int _page = 0;
  int _request = 0;
  Result<CollabPage<CollabAdminReport>>? _result;

  bool get _sessionMatches =>
      identical(widget.sessions.session, _entry) &&
      canManageCollabReports(_entry);

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
    final result = await widget.repository.load(
      status: _status,
      reason: _reason,
      page: page,
    );
    if (!mounted || !_access.value) return;
    if (isCollabReportAccessError(result.error)) {
      _deny();
      return;
    }
    if (request != _request) return;
    setState(() => _result = result);
  }

  Future<void> _open(CollabAdminReport report) async {
    if (!_access.value || ModalRoute.of(context)?.isCurrent != true) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CollabReportReviewScreen(
          reportId: report.id,
          repository: widget.repository,
          access: _access,
          onAccessLost: _deny,
          frame: widget.frame,
        ),
      ),
    );
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      await _load(_page);
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
        title: 'Collab şikâyetleri',
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
                        'Collab şikâyetleri',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  DropdownButtonFormField<CollabReportStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Şikâyet durumu',
                    ),
                    items: [
                      for (final status in CollabReportStatus.values)
                        DropdownMenuItem(
                          value: status,
                          child: Text(status.label),
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
                  DropdownButtonFormField<CollabReportReason?>(
                    initialValue: _reason,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Şikâyet nedeni',
                    ),
                    hint: const Text('Tümü'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tümü')),
                      for (final reason in CollabReportReason.values)
                        DropdownMenuItem(
                          value: reason,
                          child: Text(reason.label),
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
                              key: ValueKey(report.id),
                              title: Text(report.listingTitle),
                              subtitle: Text(
                                '${report.reason.label} · ${collabShortDate(report.reportedAt)}',
                              ),
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
            : const Center(child: Text(collabReportAccessLostMessage)),
      );
    },
  );
}
