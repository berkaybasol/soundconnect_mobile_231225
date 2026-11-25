import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../../collab/presentation/widgets/collab_management_widgets.dart'
    show collabShortDate;
import '../../../content_report/domain/content_report.dart';
import '../../data/admin_user_directory_repository.dart';
import '../../data/content_report_admin_repository.dart';
import '../../domain/admin_panel_access.dart';
import '../../domain/admin_user_directory.dart';
import '../widgets/admin_decision_reason_sheet.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_report_list.dart';
import '../widgets/admin_visual_theme.dart';
import '../widgets/application_review_widgets.dart';
import 'admin_user_detail_screen.dart';

const _queueTitle = 'Profil ve içerik şikâyetleri';

class ContentReportAdminScreen extends StatelessWidget {
  const ContentReportAdminScreen({
    super.key,
    required this.sessions,
    required this.initialSession,
    required this.repository,
    required this.userDirectory,
    this.frame,
  });

  final AuthSessionManager sessions;
  final AuthSession initialSession;
  final ContentReportAdminRepository repository;
  final AdminUserDirectoryRepository userDirectory;
  final AdminSubpageFrame? frame;

  @override
  Widget build(
    BuildContext context,
  ) => AdminReportList<ContentReportStatus, ContentReportKind, AdminContentReport>(
    sessions: sessions,
    initialSession: initialSession,
    frame: frame,
    title: _queueTitle,
    statuses: ContentReportStatus.values,
    statusLabel: (s) => s.label,
    filterTitle: 'Bildirilen öğe',
    filters: ContentReportKind.values,
    filterLabel: (k) => k.label,
    load: repository.list,
    id: (r) => r.id,
    rowTitle: (r) => r.targetLabel,
    rowSubtitle: (r) =>
        '${r.kind.label} · ${r.reason.label}\n${collabShortDate(r.reportedAt)}',
    canRead: canManageContentReports,
    isAccessError: ContentReportAdminRepository.isAccessError,
    accessMessage: ContentReportAdminRepository.accessError.message,
    review: (report, access, deny) => _ReportDetail(
      id: report.id,
      repository: repository,
      access: access,
      deny: deny,
      frame: frame,
      userDirectory: canReadAdminUsers(initialSession) ? userDirectory : null,
    ),
  );
}

class _ReportDetail extends StatefulWidget {
  const _ReportDetail({
    required this.id,
    required this.repository,
    required this.access,
    required this.deny,
    this.frame,
    this.userDirectory,
  });
  final String id;
  final ContentReportAdminRepository repository;
  final ValueListenable<bool> access;
  final VoidCallback deny;
  final AdminSubpageFrame? frame;
  final AdminUserDirectoryRepository? userDirectory;

  @override
  State<_ReportDetail> createState() => _ReportDetailState();
}

class _ReportDetailState extends State<_ReportDetail> {
  Result<AdminContentReport>? _result;
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.access.value) return;
    setState(() => _result = null);
    final result = await widget.repository.detail(widget.id);
    if (!mounted || !widget.access.value) return;
    if (ContentReportAdminRepository.isAccessError(result.error)) {
      widget.deny();
    } else {
      setState(() => _result = result);
    }
  }

  Future<void> _decide(
    BuildContext themedContext,
    AdminContentReport report,
    ContentReportDecision decision,
  ) async {
    if (_busy ||
        !widget.access.value ||
        !identical(_result?.data, report) ||
        !report.allows(decision) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      final note = await showModalBottomSheet<String>(
        context: themedContext,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => ValueListenableBuilder<bool>(
          valueListenable: widget.access,
          builder: (context, allowed, _) => allowed
              ? AdminDecisionReasonSheet(
                  heading: decision.label,
                  title: report.targetLabel,
                  impact: switch (decision) {
                    ContentReportDecision.dismiss =>
                      'Şikâyet işlem yapılmadan sonuçlandırılacak.',
                    ContentReportDecision.confirm =>
                      'İhlal bu şikâyetin karar kaydına işlenecek.',
                    ContentReportDecision.remove =>
                      'Bildirilen öğe yayından kaldırılacak.',
                  },
                  destructive: decision == ContentReportDecision.remove,
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(ContentReportAdminRepository.accessError.message),
                ),
        ),
      );
      if (!mounted ||
          note == null ||
          !widget.access.value ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final saved = await widget.repository.review(report, decision, note);
      if (!mounted || !widget.access.value) return;
      if (ContentReportAdminRepository.isAccessError(saved.error)) {
        widget.deny();
      } else if (saved.isSuccess) {
        setState(() {
          _result = saved;
          _notice = 'Karar kaydedildi.';
        });
      } else {
        // Read back the exact report before offering another decision.
        _notice = 'Karar için onay alınamadı. Güncel kaydı kontrol et.';
        await _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAccount(String userId) async {
    final directory = widget.userDirectory;
    if (directory == null ||
        !widget.access.value ||
        _busy ||
        _result?.data?.profileUserId != userId ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AdminUserDetailScreen(
          userId: userId,
          repository: directory,
          access: widget.access,
          onAccessLost: widget.deny,
          frame: widget.frame,
          backLabel: 'Şikâyet ayrıntısı',
        ),
      ),
    );
    if (mounted &&
        widget.access.value &&
        ModalRoute.of(context)?.isCurrent == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.access,
    builder: (context, allowed, _) => PopScope(
      canPop: !_busy || !allowed,
      child: ApplicationPageFrame(
        frame: widget.frame,
        title: 'Şikâyet ayrıntısı',
        backLabel: _queueTitle,
        child: Builder(
          builder: (context) {
            if (!allowed) {
              return Center(
                child: Text(ContentReportAdminRepository.accessError.message),
              );
            }
            final result = _result;
            if (result == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final report = result.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                if (_notice case final message?)
                  Semantics(liveRegion: true, child: Text(message)),
                if (report == null) ...[
                  Text(result.error!.message),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Tekrar dene'),
                  ),
                ] else ...[
                  Text(
                    report.targetLabel,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text('${report.kind.label} · ${report.status.label}'),
                  const SizedBox(height: 16),
                  if (report.status == ContentReportStatus.resolved)
                    AdminSectionCard(
                      title: 'Karar kaydı',
                      icon: Icons.fact_check_outlined,
                      children: [
                        if (report.decision case final value?)
                          Text(value.label),
                        if (report.resolutionNote case final note?) Text(note),
                        if (report.reviewer case final reviewer?)
                          ApplicationInfoLine(
                            Icons.person_outline,
                            'Kararı veren yönetici',
                            '@$reviewer',
                          ),
                        if (report.reviewedAt case final reviewed?)
                          ApplicationInfoLine(
                            Icons.schedule,
                            'Karar zamanı',
                            collabShortDate(reviewed),
                          ),
                      ],
                    ),
                  AdminSectionCard(
                    title: 'Bildirim anındaki içerik',
                    icon: Icons.article_outlined,
                    children: [
                      Text(report.evidenceText ?? report.targetLabel),
                      if (report.parentText case final parent?)
                        ApplicationInfoLine(
                          Icons.reply_outlined,
                          report.kind == ContentReportKind.comment
                              ? 'Yanıt verilen yorum'
                              : 'Paylaşılan içerik',
                          parent,
                        ),
                      if (report.profileUserId case final id?)
                        if (widget.userDirectory != null)
                          TextButton.icon(
                            onPressed: _busy ? null : () => _openAccount(id),
                            icon: const Icon(Icons.manage_accounts_outlined),
                            label: const Text('Hesap detayını aç'),
                          ),
                    ],
                  ),
                  AdminSectionCard(
                    title: 'Bildirenin beyanı',
                    icon: Icons.outlined_flag,
                    children: [
                      Text(report.reason.label),
                      if (report.description case final value?) Text(value),
                      if (report.reporter case final reporter?)
                        ApplicationInfoLine(
                          Icons.person_outline,
                          'Bildiren',
                          '@$reporter',
                        ),
                      ApplicationInfoLine(
                        Icons.schedule,
                        'Bildirim zamanı',
                        collabShortDate(report.reportedAt),
                      ),
                    ],
                  ),
                  if (report.status == ContentReportStatus.open)
                    for (final decision in ContentReportDecision.values.where(
                      report.allows,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AdminBrandButton(
                          label: decision.label,
                          icon: decision == ContentReportDecision.remove
                              ? Icons.unpublished_outlined
                              : Icons.fact_check_outlined,
                          onPressed: _busy
                              ? null
                              : () => _decide(context, report, decision),
                        ),
                      ),
                  if (report.status == ContentReportStatus.resolved)
                    TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(ContentReportStatus.resolved),
                      child: const Text('Sonuçlanmış şikâyetlere dön'),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}
