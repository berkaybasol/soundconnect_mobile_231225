import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_surface_theme.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/entities/event_plan.dart';
import '../../domain/entities/event_performer_request.dart';
import '../../domain/event_plan_repository.dart';
import 'event_plan_date_label.dart';

part 'event_plan_performer_widgets.dart';

class EventPlanPerformerScreen extends StatefulWidget {
  const EventPlanPerformerScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    this.repository,
    this.sessions,
  });
  final EventPerformerTargetType targetType;
  final String targetId;
  final EventPlanRepository? repository;
  final AuthSessionManager? sessions;
  @override
  State<EventPlanPerformerScreen> createState() => _PerformerPlansState();
}

class _PerformerPlansState extends State<EventPlanPerformerScreen>
    with WidgetsBindingObserver {
  late final EventPlanRepository _repo;
  AuthSessionManager? _sessions;
  Object? _session;
  EventPlanPage<EventPlan>? _page;
  final Set<String> _publish = {};
  bool _loading = true, _busy = false;
  bool _confirming = false;
  ModalRoute<dynamic>? _decisionDialog;
  String? _error;
  int _generation = 0;
  bool get _current =>
      _sessions == null || identical(_session, _sessions!.session);
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
    final dialog = _decisionDialog;
    if (dialog?.isActive == true) {
      dialog!.navigator?.removeRoute(dialog);
    }
    setState(() {
      _page = null;
      _publish.clear();
      _loading = false;
      _busy = false;
      _confirming = false;
      _error = 'Oturum değişti. Planları yeniden aç.';
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
      _publish.clear();
    });
    try {
      final result = await _repo.listPerformer(
        widget.targetType,
        widget.targetId,
        page: page,
      );
      if (!mounted || !_current || generation != _generation) return;
      setState(() {
        _loading = false;
        _page = result.data;
        _error = result.isSuccess
            ? null
            : result.error?.message ?? 'Planlar alınamadı.';
      });
    } catch (_) {
      if (mounted && _current && generation == _generation) {
        setState(() {
          _loading = false;
          _error = 'Planlar alınamadı. Tekrar dene.';
        });
      }
    }
  }

  Future<void> _decide(EventPlan plan, String decision) async {
    if (_busy ||
        _loading ||
        !_current ||
        ModalRoute.of(context)?.isCurrent != true ||
        _page?.items.any((p) => identical(p, plan)) != true ||
        (decision == 'WITHDRAW'
            ? !plan.withdrawAllowed
            : !plan.decisionAllowed)) {
      return;
    }
    final page = _page!.page;
    final publish = _publish.contains(plan.id);
    setState(() {
      _busy = true;
      _confirming = true;
    });
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        _decisionDialog = ModalRoute.of(dialogContext);
        return Theme(
          data: appSurfaceTheme(Theme.of(dialogContext)),
          child: _PerformerPlanDecisionDialog(
            plan: plan,
            decision: decision,
            publish: publish,
            onCancel: () => Navigator.pop(dialogContext, false),
            onConfirm: () => Navigator.pop(dialogContext, true),
          ),
        );
      },
    );
    _decisionDialog = null;
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed != true || !_current) {
      setState(() => _busy = false);
      return;
    }
    String message;
    try {
      // Refresh just before the explicit decision. A changed scope must be
      // presented again; never approve a program using an old confirmation.
      final latest = await _repo.getPerformer(plan.id);
      if (!mounted || !_current) return;
      final current = latest.data;
      if (!latest.isSuccess ||
          current == null ||
          current.version != plan.version ||
          (decision == 'WITHDRAW'
              ? !current.withdrawAllowed
              : !current.decisionAllowed)) {
        message =
            'Program değişti. Güncel tarihleri kontrol edip tekrar karar ver.';
      } else {
        final result = await _repo.decide(
          current,
          decision,
          showOnProfile: decision == 'ACCEPT' ? publish : null,
        );
        message = result.isSuccess
            ? 'Plan kararın kaydedildi.'
            : result.error?.message ??
                  'Sonuç doğrulanamadı. Planlar yenileniyor.';
      }
    } catch (_) {
      message =
          'Sonuç doğrulanamadı. Tekrar göndermeden güncel planı kontrol et.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (_current) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    await _load(page: page);
  }

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

  Widget _buildPage(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: const Text(
          'Planlı Etkinlik Davetleri',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _busy ? () async {} : _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Bir programı onaylamak, belirtilen gün ve saatlerdeki gelecek etkinliklere katılımını onaylar. Profil yayını ayrıca seçilir.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 20),
            if (_loading || (_busy && !_confirming))
              const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('Yenile'),
              ),
            ],
            if (!_loading && _page?.items.isEmpty == true)
              const Text('Bu profil için plan daveti yok.'),
            for (final plan in _page?.items ?? <EventPlan>[])
              EventPlanConsentCard(
                plan: plan,
                busy: _busy || _loading,
                showOnProfile: _publish.contains(plan.id),
                onPublicationChanged: (value) => setState(() {
                  if (value) {
                    _publish.add(plan.id);
                  } else {
                    _publish.remove(plan.id);
                  }
                }),
                onDecision: (decision) => _decide(plan, decision),
              ),
            if (_page != null && (_page!.page > 0 || _page!.hasNext))
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _busy || _loading || _page!.page == 0
                        ? null
                        : () => _load(page: _page!.page - 1),
                    child: const Text('Önceki'),
                  ),
                  TextButton(
                    onPressed:
                        _busy ||
                            _loading ||
                            !_page!.hasNext ||
                            _page!.page >= 100
                        ? null
                        : () => _load(page: _page!.page + 1),
                    child: const Text('Sonraki'),
                  ),
                ],
              ),
          ],
        ),
      ),
    ),
  );
}
