import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/error/result.dart';
import '../../data/pending_application_repository.dart';
import '../../domain/pending_application.dart';
import '../widgets/admin_panel_frame.dart';
import '../widgets/admin_visual_theme.dart';
import '../widgets/application_review_widgets.dart';

class ApplicationReviewScreen extends StatefulWidget {
  const ApplicationReviewScreen({
    super.key,
    required this.entry,
    required this.sessions,
    required this.kind,
    required this.id,
    required this.repository,
    this.frame,
  });
  final AuthSession entry;
  final AuthSessionManager sessions;
  final ApplicationKind kind;
  final String id;
  final PendingApplicationRepository repository;
  final AdminSubpageFrame? frame;

  @override
  State<ApplicationReviewScreen> createState() =>
      _ApplicationReviewScreenState();
}

class _ApplicationReviewScreenState extends State<ApplicationReviewScreen> {
  Result<PendingApplication>? _read;
  bool _reviewing = false;
  bool _sending = false;
  String _reason = '';
  Result<bool>? _write;

  bool get _authorized =>
      mounted &&
      identical(widget.entry, widget.sessions.session) &&
      widget.kind.canRead(widget.entry);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_read != null) setState(() => _read = null);
    final result = await widget.repository.detail(
      widget.entry,
      widget.kind,
      widget.id,
    );
    if (mounted) setState(() => _read = result);
  }

  Future<void> _review(
    BuildContext themedContext,
    PendingApplication item,
    bool approve,
  ) async {
    if (_reviewing ||
        _sending ||
        !_authorized ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _reviewing = true;
    final sessions = widget.sessions;
    final answer = await showModalBottomSheet<String>(
      context: themedContext,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => ListenableBuilder(
        listenable: sessions,
        builder: (context, _) => _authorized
            ? ApplicationDecisionSheet(
                item: item,
                kind: widget.kind,
                approve: approve,
                initialReason: _reason,
              )
            : const SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Başvuruları görme yetkin değişti.'),
                ),
              ),
      ),
    );
    _reviewing = false;
    if (!mounted ||
        answer == null ||
        !_authorized ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    setState(() => _sending = true);
    if (!approve) _reason = answer;
    final result = await widget.repository.decide(
      widget.entry,
      widget.kind,
      widget.id,
      approve: approve,
      reason: answer,
    );
    if (!mounted || !_authorized) return;
    _write = result;
    if (const {'access_changed', 'not_pending'}.contains(result.error?.code)) {
      setState(() {
        _sending = false;
        _read = Result.failure(result.error);
      });
      return;
    }
    // A timed-out write can still commit. Read back the authoritative decision
    // before presenting any further action, even if the POST reported an error.
    await _load();
    if (mounted) setState(() => _sending = false);
  }

  String? _notice(PendingApplication item) {
    final pending = item.status == ApplicationReviewStatus.pending;
    final write = _write;
    if (pending) {
      if (write == null) return null;
      if (write.error?.code == '1613') {
        return 'Başvuru sahibi e-posta adresini doğruladıktan sonra karar verebilirsin.';
      }
      if (const {'409', '1602'}.contains(write.error?.code)) {
        return 'Başvuru halen bekliyor. Başvuru sahibinin güncel durumu bu karara izin vermiyor.';
      }
      return 'Karar doğrulanamadı. Son kontrolde başvuru inceleme bekliyordu.';
    }
    if (write?.isSuccess == true) return null;
    if (write == null || const {'409', '1602'}.contains(write.error?.code)) {
      return 'Bu başvuru sen incelerken sonuçlandırıldı.';
    }
    return 'Güncel karar sunucudan doğrulandı.';
  }

  String _formatDate(DateTime value) =>
      DateFormat('dd.MM.yyyy HH:mm').format(value.toLocal());
  Widget _information(PendingApplication item) {
    final phone = item.phone?.trim().replaceFirstMapped(
      RegExp(r'^(0\d{3})(\d{3})(\d{2})(\d{2})$'),
      (match) => '${match[1]} ${match[2]} ${match[3]} ${match[4]}',
    );
    return ApplicationSurface(
      rows: [
        ApplicationInfoLine(Icons.phone_outlined, 'Telefon', phone),
        ApplicationInfoLine(
          Icons.person_outline,
          'Başvuran',
          item.applicantUsername,
        ),
        ApplicationInfoLine(
          Icons.calendar_today_outlined,
          'Başvuru tarihi',
          _formatDate(item.appliedAt),
        ),
        ApplicationInfoLine(Icons.home_outlined, 'Açık adres', item.address),
      ],
    );
  }

  Widget _receipt(PendingApplication item) => ApplicationSurface(
    rows: [
      ApplicationInfoLine(
        Icons.person_outline,
        'Kararı veren',
        item.reviewedByUsername,
      ),
      ApplicationInfoLine(
        Icons.schedule,
        'Karar zamanı',
        item.decisionDate == null ? null : _formatDate(item.decisionDate!),
      ),
      if (item.status == ApplicationReviewStatus.rejected)
        ApplicationInfoLine(
          Icons.chat_bubble_outline,
          'Başvuru sahibine gösterilen gerekçe',
          item.rejectionReason,
        ),
    ],
  );

  Widget _actions(BuildContext context, PendingApplication item) {
    if (item.status != ApplicationReviewStatus.pending) {
      return SizedBox(
        width: double.infinity,
        child: AdminBrandButton(
          label: 'Başvurulara dön',
          icon: Icons.arrow_back,
          onPressed: () => Navigator.pop(context),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Başvuru kararı', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (_sending)
          const LinearProgressIndicator(semanticsLabel: 'Karar kaydediliyor'),
        ApplicationReviewButtons(
          secondary: AdminBrandButton(
            label: 'Reddet',
            icon: Icons.close,
            onPressed: _sending ? null : () => _review(context, item, false),
          ),
          primary: AdminBrandButton(
            label: 'Onayla',
            icon: Icons.check,
            onPressed: _sending ? null : () => _review(context, item, true),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = ListenableBuilder(
      listenable: widget.sessions,
      builder: (context, _) {
        if (!_authorized) {
          return const Center(child: Text('Başvuruları görme yetkin değişti.'));
        }
        final result = _read;
        if (result == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final item = result.data;
        if (item == null) {
          final error = result.error;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error?.message ?? 'Başvuru bilgileri alınamadı.',
                    textAlign: TextAlign.center,
                  ),
                  if (!const {
                    'access_changed',
                    'not_pending',
                  }.contains(error?.code))
                    TextButton(
                      onPressed: _load,
                      child: const Text('Tekrar dene'),
                    ),
                ],
              ),
            ),
          );
        }
        final pending = item.status == ApplicationReviewStatus.pending;
        final notice = _notice(item);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          children: [
            ApplicationReviewHeader(item: item),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Semantics(liveRegion: true, child: Text(notice)),
                    subtitle: pending
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _sending ? null : _load,
                              child: const Text('Durumu yenile'),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            if (!pending) ...[
              const SizedBox(height: 20),
              Text(
                'Karar kaydı',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              _receipt(item),
            ],
            const SizedBox(height: 23),
            Text(
              'Başvuru bilgileri',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _information(item),
            const SizedBox(height: 22),
            _actions(context, item),
          ],
        );
      },
    );
    return ApplicationPageFrame(
      title: '${widget.kind.label} başvurusu',
      backLabel: '${widget.kind.label} başvuruları',
      frame: widget.frame,
      child: body,
    );
  }
}
