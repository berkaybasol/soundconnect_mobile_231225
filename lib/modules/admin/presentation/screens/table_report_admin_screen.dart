import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../collab/presentation/widgets/collab_management_widgets.dart'
    show collabShortDate;
import '../../../tablegroup/domain/table_group_report.dart';
import '../../data/table_report_admin_repository.dart';
import '../../domain/admin_panel_access.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_report_list.dart';
import '../widgets/admin_visual_theme.dart';
import '../widgets/application_review_widgets.dart';
import 'table_report_decision_screen.dart';

bool _accessLost(AppError? error) =>
    isAdminPanelAccessError(error) ||
    error?.code == TableReportAdminRepository.accessError.code;

class TableReportAdminScreen extends StatelessWidget {
  const TableReportAdminScreen({
    super.key,
    required this.sessions,
    required this.initialSession,
    required this.repository,
    this.frame,
  });
  final AuthSessionManager sessions;
  final AuthSession initialSession;
  final TableReportAdminRepository repository;
  final AdminSubpageFrame? frame;
  @override
  Widget build(
    BuildContext context,
  ) => AdminReportList<TableReportStatus, TableGroupReportKind, TableAdminReport>(
    sessions: sessions,
    initialSession: initialSession,
    frame: frame,
    title: 'Masa şikâyetleri',
    statuses: TableReportStatus.values,
    statusLabel: (s) => s.label,
    filterTitle: 'Şikâyet türü',
    filters: TableGroupReportKind.values,
    filterLabel: (k) => k.label,
    load: repository.list,
    id: (r) => r.id,
    rowTitle: (r) => r.title,
    rowSubtitle: (r) =>
        '${r.kind.label} · ${r.reason.label}\n${collabShortDate(r.reportedAt)}',
    canRead: canManageTableReports,
    isAccessError: _accessLost,
    accessMessage: TableReportAdminRepository.accessError.message,
    review: (r, access, deny) => _TableReview(
      id: r.id,
      repository: repository,
      access: access,
      deny: deny,
      frame: frame,
    ),
  );
}

class _TableReview extends StatefulWidget {
  const _TableReview({
    required this.id,
    required this.repository,
    required this.access,
    required this.deny,
    this.frame,
  });
  final String id;
  final TableReportAdminRepository repository;
  final ValueListenable<bool> access;
  final VoidCallback deny;
  final AdminSubpageFrame? frame;
  @override
  State<_TableReview> createState() => _TableReviewState();
}

class _TableReviewState extends State<_TableReview> {
  Result<TableAdminReport>? _result;
  String? _notice;
  bool _sending = false;
  final _scroll = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

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
    if (_accessLost(result.error)) {
      widget.deny();
      return;
    }
    setState(() => _result = result);
  }

  Future<void> _decide(TableAdminReport report) async {
    if (_sending ||
        !widget.access.value ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final input = await Navigator.of(context).push<TableReviewInput>(
      MaterialPageRoute(
        builder: (_) => TableReportDecisionScreen(
          report: report,
          access: widget.access,
          frame: widget.frame,
        ),
      ),
    );
    if (!mounted ||
        input == null ||
        !widget.access.value ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() {
      _sending = true;
      _notice = null;
    });
    final result = await widget.repository.review(
      report,
      input.decision,
      input.note,
    );
    if (!mounted || !widget.access.value) return;
    if (_accessLost(result.error)) {
      widget.deny();
      return;
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (result.isSuccess) {
      setState(() {
        _result = result;
        _sending = false;
        _notice = 'Karar kaydedildi.';
      });
    } else {
      // A lost acknowledgement and a concurrent decision both require the current record.
      setState(() {
        _sending = false;
        _notice =
            'Karar için onay alınamadı. Şikâyetin güncel kaydını kontrol et.';
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.access,
    builder: (context, allowed, _) => PopScope(
      canPop: !_sending || !allowed,
      child: ApplicationPageFrame(
        title: 'Şikâyet ayrıntısı',
        backLabel: 'Masa şikâyetleri',
        frame: widget.frame,
        child: !allowed
            ? Center(
                child: Text(TableReportAdminRepository.accessError.message),
              )
            : _result == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                children: [
                  if (_notice case final notice?)
                    Semantics(liveRegion: true, child: Text(notice)),
                  if (_result?.data case final report?) ...[
                    Text(
                      report.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text('${report.kind.label} · ${report.status.label}'),
                    const SizedBox(height: 16),
                    if (report.status == TableReportStatus.resolved)
                      AdminSectionCard(
                        title: 'Karar kaydı',
                        icon: Icons.fact_check_outlined,
                        children: [
                          Text(report.decision?.label ?? 'Sonuçlanmış'),
                          Text(report.reviewNote ?? 'Gerekçe bulunamadı.'),
                          ApplicationInfoLine(
                            Icons.person_outline,
                            'Kararı veren yönetici',
                            _account(report.reviewer),
                          ),
                          ApplicationInfoLine(
                            Icons.schedule,
                            'Karar zamanı',
                            collabShortDate(report.reviewedAt),
                          ),
                        ],
                      ),
                    AdminSectionCard(
                      title: 'Bildirenin beyanı',
                      icon: Icons.outlined_flag,
                      children: [
                        Text(
                          report.reason.label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (report.statement case final statement?)
                          Text(statement),
                        ApplicationInfoLine(
                          Icons.person_outline,
                          'Bildiren',
                          _account(report.reporter),
                        ),
                        ApplicationInfoLine(
                          Icons.schedule,
                          'Bildirim zamanı',
                          collabShortDate(report.reportedAt),
                        ),
                      ],
                    ),
                    _Evidence(report),
                    AdminSectionCard(
                      title: 'Masa bilgisi',
                      icon: Icons.event_outlined,
                      children: [
                        if (report.venue != null) Text(report.venue!),
                        if (report.district != null || report.city != null)
                          Text(
                            [report.district, report.city].nonNulls.join(' · '),
                          ),
                        if (report.meetingAt != null)
                          Text(collabShortDate(report.meetingAt)),
                        ApplicationInfoLine(
                          Icons.info_outline,
                          'Güncel durum',
                          report.removed
                              ? 'Yayından kaldırıldı'
                              : report.active
                              ? 'Açık'
                              : 'Kapalı',
                        ),
                      ],
                    ),
                    if (report.status == TableReportStatus.open)
                      AdminBrandButton(
                        label: _sending ? 'Kaydediliyor…' : 'Karar ver',
                        icon: Icons.fact_check_outlined,
                        onPressed: _sending ? null : () => _decide(report),
                      )
                    else
                      AdminBrandButton(
                        label: 'Sonuçlanmış şikâyetlere dön',
                        icon: Icons.arrow_back,
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(TableReportStatus.resolved),
                      ),
                  ] else ...[
                    Text(_result!.error!.message),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Tekrar dene'),
                    ),
                  ],
                ],
              ),
      ),
    ),
  );
}

String _account(String? username) =>
    username == null ? 'Hesap bilgisi bulunmuyor' : '@$username';

class _Evidence extends StatelessWidget {
  const _Evidence(this.report);
  final TableAdminReport report;
  @override
  Widget build(BuildContext context) {
    final (title, icon, content) = switch (report.kind) {
      TableGroupReportKind.message => (
        'Bildirilen mesaj',
        Icons.chat_bubble_outline,
        [
          Text(report.message ?? 'Mesaj içeriği bulunmuyor.'),
          ApplicationInfoLine(
            Icons.person_outline,
            'Gönderen',
            _account(report.sender),
          ),
          ApplicationInfoLine(
            Icons.schedule,
            'Mesaj zamanı',
            collabShortDate(report.messageSentAt),
          ),
        ],
      ),
      TableGroupReportKind.listing => (
        'Bildirim anındaki ilan',
        Icons.article_outlined,
        [
          Text(report.tableDescription ?? 'İlan açıklaması bulunmuyor.'),
          ApplicationInfoLine(
            Icons.person_outline,
            'Masa sahibi',
            _account(report.owner),
          ),
        ],
      ),
      TableGroupReportKind.incident => (
        'Katılım kaydı',
        Icons.group_outlined,
        [
          Text(switch (report.membershipEnd) {
            'LEFT' => 'Bildiren kişi masadan ayrıldı.',
            'KICKED' => 'Bildiren kişi masadan çıkarıldı.',
            null =>
              'Bildiren kişi, bildirim sırasında masa sahibi veya kabul edilmiş katılımcıydı.',
            _ => 'Bildiren kişinin katılımı masa kapanınca sona erdi.',
          }),
          if (report.membershipEndedAt != null)
            ApplicationInfoLine(
              Icons.schedule,
              'Katılımın sona erdiği zaman',
              collabShortDate(report.membershipEndedAt),
            ),
        ],
      ),
    };
    return AdminSectionCard(
      title: title,
      icon: icon,
      description: 'Sunucu kaydı',
      children: content,
    );
  }
}
