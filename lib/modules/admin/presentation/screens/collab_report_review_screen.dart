import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/result.dart';
import '../../../collab/domain/collab_types.dart';
import '../../../collab/presentation/widgets/collab_management_widgets.dart';
import '../../data/collab_report_admin_repository.dart';
import '../../domain/collab_report_admin.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_visual_theme.dart';
import '../widgets/application_review_widgets.dart';

const collabReportAccessLostMessage =
    'Collab şikâyetlerini inceleme yetkin değişti.';

String? _accountLabel(String? username, String? userId) {
  final name = username?.trim();
  return name == null || name.isEmpty ? userId : '@$name';
}

class CollabReportReviewScreen extends StatefulWidget {
  const CollabReportReviewScreen({
    super.key,
    required this.reportId,
    required this.repository,
    required this.access,
    required this.onAccessLost,
    this.frame,
  });
  final String reportId;
  final CollabReportAdminRepository repository;
  final ValueListenable<bool> access;
  final VoidCallback onAccessLost;
  final AdminSubpageFrame? frame;

  @override
  State<CollabReportReviewScreen> createState() => _CollabReportReviewState();
}

class _CollabReportReviewState extends State<CollabReportReviewScreen> {
  Result<CollabAdminReport>? _result;
  final _scroll = ScrollController(keepScrollOffset: false);
  bool _loading = false;
  bool _reviewing = false;
  bool _sending = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading || !widget.access.value) return;
    _loading = true;
    setState(() => _result = null);
    final result = await widget.repository.detail(widget.reportId);
    if (!mounted || !widget.access.value) return;
    _loading = false;
    if (isCollabReportAccessError(result.error)) {
      widget.onAccessLost();
      return;
    }
    setState(() => _result = result);
  }

  Future<void> _review(
    BuildContext themedContext,
    CollabAdminReport report,
    CollabReportDecision decision,
  ) async {
    if (_reviewing ||
        !widget.access.value ||
        !identical(_result?.data, report) ||
        report.status != CollabReportStatus.open ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _reviewing = true);
    try {
      final note = await showModalBottomSheet<String>(
        context: themedContext,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => ValueListenableBuilder<bool>(
          valueListenable: widget.access,
          builder: (context, allowed, _) => allowed
              ? _DecisionSheet(decision: decision, title: report.listingTitle)
              : const SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(collabReportAccessLostMessage),
                  ),
                ),
        ),
      );
      if (note == null ||
          !mounted ||
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
        decision: decision,
        note: note,
      );
      if (!mounted || !widget.access.value) return;
      if (_scroll.hasClients) _scroll.jumpTo(0);
      if (result.isSuccess) {
        setState(() => _result = result);
      } else if (isCollabReportAccessError(result.error)) {
        widget.onAccessLost();
      } else {
        // A concurrent decision or a lost POST response must be resolved from
        // this exact report before another action becomes available.
        _notice = isCollabReportConflict(result.error)
            ? 'Şikâyet sen incelerken değişti. Güncel kaydı kontrol et.'
            : 'Karar için onay alınamadı. Şikâyetin güncel durumunu kontrol et.';
        await _load();
      }
    } finally {
      if (mounted) {
        setState(() {
          _reviewing = false;
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.access,
    builder: (context, allowed, _) => PopScope(
      canPop: !_sending || !allowed,
      child: ApplicationPageFrame(
        frame: widget.frame,
        title: 'Şikâyet ayrıntısı',
        backLabel: 'Collab şikâyetleri',
        child: Builder(
          builder: (context) {
            if (!allowed) {
              return const Center(child: Text(collabReportAccessLostMessage));
            }
            final result = _result;
            if (result == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final report = result.data;
            return ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              children: [
                if (_notice case final message?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(liveRegion: true, child: Text(message)),
                  ),
                if (report == null) ...[
                  Text(result.error!.message),
                  TextButton(
                    onPressed: _load,
                    child: const Text('Tekrar dene'),
                  ),
                ] else ...[
                  Semantics(
                    header: true,
                    child: Text(
                      report.listingTitle,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    report.status.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 20),
                  if (report.status != CollabReportStatus.open)
                    AdminSectionCard(
                      title: 'Karar kaydı',
                      icon: Icons.fact_check_outlined,
                      children: [
                        Text(
                          report.resolutionNote ??
                              'Karar gerekçesi kaydedilmemiş.',
                        ),
                        if (report.reviewedAt case final date?)
                          ApplicationInfoLine(
                            Icons.schedule,
                            'Karar zamanı',
                            collabShortDate(date),
                          ),
                        if (_accountLabel(
                              report.reviewedByUsername,
                              report.reviewedByUserId,
                            )
                            case final reviewer?)
                          ApplicationInfoLine(
                            Icons.person_outline,
                            'Kararı veren yönetici',
                            reviewer,
                          ),
                      ],
                    ),
                  AdminSectionCard(
                    title: 'Şikâyet',
                    icon: Icons.outlined_flag,
                    children: [
                      Text(
                        report.reason.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (report.details case final details?) ...[
                        const SizedBox(height: 6),
                        Text(details),
                      ],
                      const SizedBox(height: 8),
                      Text(collabShortDate(report.reportedAt)),
                      ApplicationInfoLine(
                        Icons.person_outline,
                        'Bildiren',
                        _accountLabel(
                          report.reporterUsername,
                          report.reporterUserId,
                        ),
                      ),
                    ],
                  ),
                  _ListingEvidence(report: report),
                  ApplicationSurface(
                    rows: [
                      ApplicationInfoLine(
                        Icons.campaign_outlined,
                        'İlanın güncel durumu',
                        collabListingStatusLabel(report.listingStatus),
                      ),
                    ],
                  ),
                  if (report.status == CollabReportStatus.open) ...[
                    const SizedBox(height: 20),
                    if (_sending)
                      const LinearProgressIndicator(
                        semanticsLabel: 'Karar kaydediliyor',
                      ),
                    for (final decision in CollabReportDecision.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AdminBrandButton(
                          label: decision.label,
                          icon: decision == CollabReportDecision.dismiss
                              ? Icons.task_alt
                              : Icons.unpublished_outlined,
                          onPressed: _reviewing
                              ? null
                              : () => _review(context, report, decision),
                        ),
                      ),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _ListingEvidence extends StatelessWidget {
  const _ListingEvidence({required this.report});
  final CollabAdminReport report;

  @override
  Widget build(BuildContext context) {
    final specialty = [
      report.wantedType.label,
      report.instrument?.name,
      report.branch?.label,
      report.customSpecialty,
    ].whereType<String>().join(' · ');
    return AdminSectionCard(
      title: report.hasListingEvidence
          ? 'Bildirim anındaki ilan'
          : 'İlan bilgileri',
      description: report.hasListingEvidence
          ? null
          : 'İlanın bildirim anındaki hali doğrulanamıyor.',
      icon: Icons.article_outlined,
      children: [
        Text(report.listingDescription),
        const SizedBox(height: 10),
        ApplicationInfoLine(
          Icons.person_outline,
          'İlan sahibi',
          report.publisherDisplayName,
        ),
        ApplicationInfoLine(
          Icons.location_on_outlined,
          'Şehir',
          report.city.name,
        ),
        ApplicationInfoLine(
          Icons.music_note_outlined,
          'Aranan profil',
          specialty,
        ),
        ApplicationInfoLine(
          Icons.event_repeat,
          'Çalışma düzeni',
          report.cadence.label,
        ),
        if (report.listingGenres.isNotEmpty)
          ApplicationInfoLine(
            Icons.library_music_outlined,
            'Müzik türleri',
            report.listingGenres.join(', '),
          ),
        if (report.scheduledAt case final date?)
          ApplicationInfoLine(
            Icons.event_outlined,
            'Etkinlik zamanı',
            collabShortDate(date),
          ),
        if (report.feeAmountMinor case final amount?)
          ApplicationInfoLine(
            Icons.payments_outlined,
            'Ücret',
            NumberFormat.currency(
              locale: 'tr_TR',
              symbol: report.currency ?? '',
              decimalDigits: 2,
            ).format(amount / 100),
          ),
        if (report.hasListingEvidence)
          ApplicationInfoLine(
            Icons.campaign_outlined,
            'Bildirim anındaki durum',
            collabListingStatusLabel(report.listingStatusAtReport),
          ),
      ],
    );
  }
}

class _DecisionSheet extends StatefulWidget {
  const _DecisionSheet({required this.decision, required this.title});
  final CollabReportDecision decision;
  final String title;

  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final _form = GlobalKey<FormState>();
  String _note = '';
  bool _closed = false;

  void _close(String? value) {
    if (_closed || ModalRoute.of(context)?.isCurrent != true) return;
    _closed = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.decision.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                widget.decision == CollabReportDecision.removeListing
                    ? 'İlan yayından kaldırılacak. Bu ilana ait diğer açık şikâyetler de aynı gerekçeyle sonuçlandırılacak.'
                    : 'Bu şikâyet kapatılacak. İlan mevcut durumunu koruyacak.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                minLines: 2,
                maxLines: 5,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Karar gerekçesi',
                  helperText: '5–500 karakter',
                  counterText: '',
                ),
                onChanged: (value) => _note = value,
                validator: (value) => isValidCollabResolutionNote(value ?? '')
                    ? null
                    : '5–500 karakterlik bir gerekçe yaz.',
              ),
              const SizedBox(height: 16),
              ApplicationReviewButtons(
                secondary: TextButton(
                  onPressed: () => _close(null),
                  child: const Text('Vazgeç'),
                ),
                primary: AdminBrandButton(
                  label: 'Kararı kaydet',
                  icon: Icons.check,
                  onPressed: () {
                    if (_form.currentState!.validate()) _close(_note.trim());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
