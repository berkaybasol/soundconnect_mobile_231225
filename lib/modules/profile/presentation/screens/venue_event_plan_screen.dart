import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/app_error.dart';
import '../../../../core/error/result.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/entities/event_plan.dart';
import '../../domain/entities/venue_owner_profile.dart';
import '../../domain/event_plan_repository.dart';
import 'venue_weekly_calendar_editor_screen.dart';
import 'event_plan_date_label.dart';

part 'venue_event_plan_screen_sections.dart';

class VenueEventPlanScreen extends StatefulWidget {
  const VenueEventPlanScreen({
    super.key,
    required this.planId,
    required this.ownerProfile,
    this.repository,
    this.sessions,
  });
  final String planId;
  final VenueOwnerProfile ownerProfile;
  final EventPlanRepository? repository;
  final AuthSessionManager? sessions;
  @override
  State<VenueEventPlanScreen> createState() => _OwnerPlanState();
}

class _OwnerPlanState extends State<VenueEventPlanScreen>
    with WidgetsBindingObserver {
  late final EventPlanRepository _repo;
  AuthSessionManager? _sessions;
  Object? _session;
  EventPlan? _plan;
  EventPlanPage<EventPlanOccurrence>? _page;
  bool _loading = true, _busy = false;
  bool _editing = false;
  ModalRoute<dynamic>? _actionDialog;
  String? _error;
  int _generation = 0;
  final Stopwatch _elapsed = Stopwatch()..start();
  Duration _receivedAt = Duration.zero;
  bool get _current =>
      _sessions == null ||
      identical(_sessions!.session, _session) &&
          _sessions!.session.userId == widget.ownerProfile.ownerUserId;
  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? serviceLocator<EventPlanRepository>();
    _sessions =
        widget.sessions ??
        (serviceLocator.isRegistered<AuthSessionManager>()
            ? serviceLocator<AuthSessionManager>()
            : null);
    _session = _sessions?.session;
    _sessions?.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _sessionChanged() {
    if (!mounted || _current) return;
    ++_generation;
    final dialog = _actionDialog;
    if (dialog?.isActive == true) {
      dialog!.navigator?.removeRoute(dialog);
    }
    setState(() {
      _plan = null;
      _page = null;
      _loading = false;
      _busy = false;
      _editing = false;
      _error = 'Oturum değişti. Planı yeniden aç.';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) unawaited(_load());
  }

  Future<void> _load({int page = 0}) async {
    if (!_current) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _page = null;
    });
    try {
      final plan = await _repo.getOwner(widget.planId);
      if (!mounted || generation != _generation || !_current) return;
      if (!plan.isSuccess ||
          plan.data == null ||
          plan.data!.definition.venueId != widget.ownerProfile.venueId) {
        setState(() {
          _plan = null;
          _loading = false;
          _error = plan.error?.message ?? 'Plan bulunamadı.';
        });
        return;
      }
      final result = await _repo.occurrences(widget.planId, page: page);
      if (!mounted || generation != _generation || !_current) return;
      _receivedAt = _elapsed.elapsed;
      setState(() {
        _plan = plan.data;
        _page = result.data;
        _loading = false;
        _error = result.isSuccess
            ? null
            : result.error?.message ?? 'Tarihler alınamadı.';
      });
    } catch (_) {
      if (mounted && generation == _generation && _current) {
        setState(() {
          _loading = false;
          _error = 'Plan alınamadı. Tekrar dene.';
        });
      }
    }
  }

  bool _upcoming(EventPlanOccurrence item) {
    if (_plan == null || !item.prepared) return false;
    final parts =
        (item.template?.startTime ??
                item.event?.startTime ??
                _plan!.definition.template.startTime)
            .split(':');
    final start = DateTime.utc(
      item.eventDate.year,
      item.eventDate.month,
      item.eventDate.day,
      int.tryParse(parts.first) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    ).subtract(const Duration(hours: 3));
    return start.isAfter(_plan!.serverNow.add(_elapsed.elapsed - _receivedAt));
  }

  Future<Result<void>> _save(Future<Result<EventPlan>> Function() write) async {
    if (!_current) {
      return const Result.failure(
        AppError(
          code: 'event_plan_session_changed',
          message: 'Oturum değişti.',
        ),
      );
    }
    try {
      final result = await write();
      if (!result.isSuccess) return Result.failure(result.error);
      return const Result.success(null);
    } catch (_) {
      return const Result.failure(
        AppError(
          code: 'event_plan_unknown',
          message: 'Kayıt sonucu doğrulanamadı. Listeyi kontrol et.',
        ),
      );
    }
  }

  Future<void> _edit({EventPlanOccurrence? occurrence}) async {
    final plan = _plan;
    if (plan == null ||
        _busy ||
        _loading ||
        !_current ||
        (occurrence != null && !_upcoming(occurrence))) {
      return;
    }
    final template = occurrence?.template ?? plan.definition.template;
    if (occurrence?.status == 'OVERRIDDEN' && occurrence?.template == null) {
      _notice('Bu tarihin düzenleme bilgileri alınamadı. Listeyi yenile.');
      return;
    }
    setState(() {
      _busy = true;
      _editing = true;
    });
    await showVenueEventDraft(
      context,
      ownerProfile: widget.ownerProfile,
      title: occurrence == null
          ? 'Gelecek etkinlikleri düzenle'
          : 'Yalnız bu tarihi düzenle',
      submitLabel: 'Değişikliği kaydet',
      initialDraft: template.toDraft(
        occurrence?.eventDate ?? plan.definition.startDate,
      ),
      initialPlan: occurrence == null ? plan.definition : null,
      editingPlanId: occurrence == null ? plan.id : null,
      editingPlanVersion: occurrence == null ? plan.version : null,
      performerName: occurrence?.event?.performerName ?? plan.performerName,
      posterUrl: occurrence?.event?.posterImage ?? plan.posterUrl,
      onSave: (draft) => _save(
        () => _repo.editOccurrence(
          plan,
          occurrence!,
          eventDate: draft.eventDate,
          template: EventPlanTemplate.fromDraft(draft),
        ),
      ),
      onPlanSave: occurrence == null
          ? (definition, _) => _save(() => _repo.update(plan, definition))
          : null,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _editing = false;
    });
    await _load(page: _page?.page ?? 0);
  }

  Future<void> _act(String action, {EventPlanOccurrence? occurrence}) async {
    final plan = _plan;
    if (plan == null || _busy || _loading || !_current) return;
    var cancelFuture = action == 'cancel';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        _actionDialog = ModalRoute.of(dialogContext);
        return Theme(
          data: appSurfaceTheme(Theme.of(dialogContext)),
          child: StatefulBuilder(
            builder: (context, update) => AlertDialog(
              scrollable: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 12, 20, 20),
              titleTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
              contentTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.5,
              ),
              title: Text(
                action == 'stop'
                    ? 'Planı durdur'
                    : action == 'cancel'
                    ? 'Gelecek etkinlikleri iptal et'
                    : 'Bu tarihi atla',
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (action == 'skip') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      child: Text(
                        eventPlanDateLabel(occurrence!.eventDate),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    action == 'cancel'
                        ? 'Bu plandaki henüz başlamamış etkinlikler iptal edilir. Geçmiş etkinlikler değişmez.'
                        : action == 'stop'
                        ? 'Yeni etkinlik tarihleri hazırlanmayacak.'
                        : 'Bu etkinlik kaldırılır ve bu tarih yeniden hazırlanmaz. Diğer tarihler değişmez.',
                  ),
                  if (action == 'stop') ...[
                    const SizedBox(height: 14),
                    CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: AppColors.brandGradient.last,
                      checkColor: AppColors.onAccent,
                      checkboxShape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      tileColor: Theme.of(context).colorScheme.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      title: const Text(
                        'Hazırlanmış gelecek etkinlikleri de iptal et',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Seçmezsen hazırlanmış etkinlikler korunur.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                      value: cancelFuture,
                      onChanged: (v) => update(() => cancelFuture = v == true),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant,
                    minimumSize: const Size(72, 48),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Vazgeç'),
                ),
                GradientOutline(
                  radius: 10,
                  strokeWidth: .9,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      action == 'stop'
                          ? 'Durdur'
                          : action == 'cancel'
                          ? 'Etkinlikleri iptal et'
                          : 'Tarihi atla',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    _actionDialog = null;
    if (!mounted ||
        confirmed != true ||
        !_current ||
        !identical(plan, _plan) ||
        (occurrence != null && !_upcoming(occurrence))) {
      return;
    }
    setState(() => _busy = true);
    final result = await _save(
      () => action == 'stop' || action == 'cancel'
          ? _repo.stop(plan, cancelFuture: cancelFuture)
          : _repo.skipOccurrence(plan, occurrence!),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (_current) {
      _notice(
        result.isSuccess
            ? 'Plan güncellendi.'
            : result.error?.message ?? 'Sonuç doğrulanamadı.',
      );
    }
    await _load(page: _page?.page ?? 0);
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  @override
  void dispose() {
    ++_generation;
    _sessions?.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: appSurfaceTheme(Theme.of(context)),
    child: Builder(builder: _buildPage),
  );

  Widget _buildPage(BuildContext context) {
    final plan = _plan;
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Planlı Etkinlik',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Planı yenile',
              onPressed: _busy || _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _busy ? () async {} : _load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (_loading || (_busy && !_editing))
                const LinearProgressIndicator(),
              if (_error != null) ...[
                Text(_error!),
                TextButton(
                  onPressed: _busy ? null : _load,
                  child: const Text('Yenile'),
                ),
              ],
              if (plan != null && _current) ...[
                _buildPlanSummary(context, plan),
                const SizedBox(height: 12),
                _buildPerformerStatus(context, plan),
                const SizedBox(height: 28),
                const Text(
                  'Hazırlanan tarihler',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Bir tarihi düzenlemek diğerlerini değiştirmez.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                if (_page?.items.isEmpty == true)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Henüz hazırlanmış tarih yok. Başlangıç yaklaşınca etkinlikler burada görünür.',
                    ),
                  ),
                for (final occurrence
                    in _page?.items ?? <EventPlanOccurrence>[])
                  _buildOccurrence(context, occurrence),
                if (_page != null && (_page!.page > 0 || _page!.hasNext))
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: _page!.page > 0 && !_busy && !_loading
                            ? () => _load(page: _page!.page - 1)
                            : null,
                        child: const Text('Önceki'),
                      ),
                      TextButton(
                        onPressed:
                            _page!.hasNext &&
                                _page!.page < 100 &&
                                !_busy &&
                                !_loading
                            ? () => _load(page: _page!.page + 1)
                            : null,
                        child: const Text('Sonraki'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
