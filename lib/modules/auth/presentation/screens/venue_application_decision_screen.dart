import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/push/push_coordinator.dart';
import '../../../../core/push/push_provider.dart';
import '../../../notification/data/notification_target_repository.dart';
import '../../../notification/domain/entities/app_notification.dart';
import '../../../notification/presentation/cubit/notification_cubit.dart';
import '../../../notification/presentation/notification_target_read.dart';
import '../../data/venue_application_repository.dart';

/// Own current application only. Opening this screen never mounts the inbox or
/// grants business access from a notification/status field.
class VenueApplicationDecisionScreen extends StatefulWidget {
  const VenueApplicationDecisionScreen({super.key, this.target});
  final PushTarget? target;
  @override
  State<VenueApplicationDecisionScreen> createState() =>
      _VenueApplicationDecisionScreenState();
}

class _VenueApplicationDecisionScreenState
    extends State<VenueApplicationDecisionScreen>
    with WidgetsBindingObserver, RouteAware {
  late final _sessions = serviceLocator<AuthSessionManager>();
  late final _session = _sessions.session;
  late final _repository = serviceLocator<VenueApplicationRepository>();
  late final _targets = serviceLocator<NotificationTargetRepository>();
  late final _push = serviceLocator.isRegistered<PushCoordinator>()
      ? serviceLocator<PushCoordinator>()
      : null;
  VenueApplicationDetail? _detail;
  AppNotification? _notification;
  String? _error;
  bool _busy = false, _acked = false, _ackBusy = false, _ackFailed = false;
  bool _promotionAttempted = false, _promotionFailed = false;
  bool _promotionInFlight = false;
  int? _promotionCredentialRevision;
  AuthSession? _promotionSuccessor;
  ModalRoute<dynamic>? _route;
  int _foregroundRevision = 0;
  bool get _current =>
      mounted &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      identical(_sessions.session, _session) &&
      _session.isAuthenticated &&
      (_session.isActive || _session.isVenueApplicationSession) &&
      ModalRoute.of(context)?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    _session;
    _sessions.addListener(_onSessionChanged);
    _foregroundRevision = _push?.foregroundRevision ?? 0;
    _push?.addListener(_onPush);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  void _onSessionChanged() {
    if (!mounted || identical(_sessions.session, _session)) return;
    if (_hasPromotionPresentation) return;
    final next = _sessions.session;
    final detail = _detail;
    // The manager commits this screen's signed promotion before the app resets
    // routes in the next frame. Preserve only that exact successor's existing
    // presentation; _current still forbids all predecessor requests and ACKs.
    if (_promotionSuccessor == null &&
        _promotionInFlight &&
        _promotionCredentialRevision == _sessions.credentialRevision &&
        _session.isVenueApplicationSession &&
        detail?.status == 'APPROVED' &&
        detail?.id == _session.applicationId &&
        detail?.applicantUserId == _session.userId &&
        next.isAuthenticated &&
        next.isActive &&
        next.userId == _session.userId &&
        next.hasAnyRole(const ['ROLE_VENUE']) &&
        next.sessionScope == null &&
        next.applicationId == null &&
        !next.requiresListenerProfileChoice) {
      setState(() {
        _promotionSuccessor = next;
        _busy = true;
        _error = null;
      });
      return;
    }
    setState(() {
      _promotionInFlight = false;
      _promotionSuccessor = null;
      _detail = null;
      _notification = null;
      _busy = false;
      _error = 'Oturum değişti. Başvurunu yeniden aç.';
    });
  }

  bool get _hasPromotionPresentation =>
      _promotionSuccessor != null &&
      identical(_sessions.session, _promotionSuccessor) &&
      _sessions.credentialRevision == _promotionCredentialRevision;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      notificationTargetRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) notificationTargetRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_current) unawaited(_finishDecision());
    });
  }

  Future<void> _support() async {
    if (!_current) return;
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.https('wa.me', '/905378581093', {
          'text':
              'Merhaba, SoundConnect mekan başvurum hakkında bilgi almak istiyorum.',
        }),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      /* Existing support target may have no local handler. */
    }
    if (!mounted || !_current || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      appSnackBar(
        context,
        tone: AppSnackBarTone.error,
        content: const Text('WhatsApp bağlantısı açılamadı.'),
      ),
    );
  }

  void _onPush() {
    final revision = _push?.foregroundRevision ?? 0;
    if (revision == _foregroundRevision) return;
    _foregroundRevision = revision;
    if (_current) unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _current) unawaited(_load());
  }

  Future<void> _load() async {
    if (!_current || _busy || _promotionAttempted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? id = _session.applicationId;
      AppNotification? notification;
      final target = widget.target;
      if (target != null) {
        final resolved = await _targets.resolve(target, _session);
        if (!_current) return;
        notification = resolved.data;
        if (!resolved.isSuccess ||
            notification == null ||
            !target.isVenueApplication) {
          throw const FormatException('Unavailable notification');
        }
        id = notification.payload['applicationId'] as String?;
      }
      if (id == null) {
        throw const FormatException('Missing application');
      }
      final result = await _repository.get(id, _session);
      if (!_current) return;
      final detail = result.data;
      if (!result.isSuccess ||
          detail == null ||
          (notification != null &&
              notification.payload['status'] != detail.status)) {
        throw const FormatException('Unavailable decision');
      }
      setState(() {
        _detail = detail;
        _notification = notification;
      });
      // ACK after the authenticated current decision has a presented frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_current && identical(_detail, detail)) {
          unawaited(_finishDecision());
        }
      });
    } catch (_) {
      if (_current) {
        setState(() {
          _detail = null;
          _error = VenueApplicationRepository.unavailable.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishDecision({bool retryAck = false}) async {
    if (!_current || _detail == null || _ackBusy) return;
    if (widget.target == null && _detail?.status == 'APPROVED') {
      // A cold native tap may arrive after the pending home has loaded.
      // Let that exact target take over before exchanging its scoped bearer.
      await _push?.start();
      if (!_current || _push?.pending != null) return;
    }
    if (_ackFailed && !retryAck) return;
    await _acknowledge();
    if (_current && !_promotionAttempted) await _continue();
  }

  Future<void> _acknowledge() async {
    final notification = _notification;
    if (!_current || notification == null || _acked || _ackBusy) return;
    if (notification.read) {
      _acked = true;
      return;
    }
    setState(() => _ackBusy = true);
    final result = await _targets.acknowledge(notification, _session);
    // Another valid route may cover this one while the ACK is in flight.
    // Releasing UI work never applies old-session semantic state.
    if (mounted) setState(() => _ackBusy = false);
    if (!mounted || !identical(_sessions.session, _session)) return;
    setState(() {
      _acked = result.isSuccess;
      _ackFailed = !result.isSuccess;
    });
    if (!result.isSuccess) return;
    if (_session.isActive && serviceLocator.isRegistered<NotificationCubit>()) {
      await serviceLocator<NotificationCubit>().applyConfirmedExternalRead(
        notification,
        _session,
      );
    } else {
      await _push?.reconcileDelivered();
    }
  }

  Future<void> _continue() async {
    final detail = _detail;
    if (!_current ||
        _busy ||
        _ackBusy ||
        (_notification != null && !_acked) ||
        detail?.status != 'APPROVED') {
      return;
    }
    _promotionAttempted = true;
    if (!_session.isVenueApplicationSession) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pushReplacementNamed(AppRoutes.venueProfile);
      messenger.showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.success,
          duration: const Duration(seconds: 3),
          content: const Text('Mekân başvurun onaylandı. Profilin hazır!'),
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _promotionFailed = false;
      _error = null;
    });
    _promotionCredentialRevision = _sessions.credentialRevision;
    _promotionInFlight = true;
    final result = await _repository.promote(detail!.id, _session);
    _promotionInFlight = false;
    // SoundConnectApp observes the signed session replacement and resets routes.
    if (!mounted || !identical(_sessions.session, _session)) return;
    setState(() {
      _busy = false;
      if (!result.isSuccess) {
        _promotionFailed = true;
        _error =
            'Profilin şu anda açılamıyor. Bağlantını kontrol edip tekrar dene.';
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    notificationTargetRouteObserver.unsubscribe(this);
    _push?.removeListener(_onPush);
    _sessions.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail =
        identical(_sessions.session, _session) || _hasPromotionPresentation
        ? _detail
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Başvuru durumu')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.navBlueDeep,
              Theme.of(context).colorScheme.surfaceContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_busy && detail == null)
                    const CircularProgressIndicator(),
                  if (detail != null) ...[
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        colors: AppColors.decorativeGradient,
                      ).createShader(bounds),
                      child: Icon(
                        detail.status == 'REJECTED'
                            ? Icons.info_outline_rounded
                            : Icons.verified_outlined,
                        size: 44,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      detail.venueName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      switch (detail.status) {
                        'APPROVED' => 'Mekân başvurun onaylandı.',
                        'REJECTED' => 'Mekân başvurun reddedildi.',
                        _ => 'Mekân başvurun inceleniyor.',
                      },
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(switch (detail.status) {
                      'APPROVED' =>
                        _promotionFailed
                            ? 'Profiline geçiş tamamlanamadı.'
                            : 'Profilin açılıyor…',
                      'REJECTED' =>
                        'Başvurunla ilgili bilgi için destek@soundconnect.com.tr adresinden bize ulaşabilirsin.',
                      _ => 'Sonuçlandığında burada görebilirsin.',
                    }, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    if (detail.status == 'APPROVED' && _promotionFailed)
                      FilledButton(
                        onPressed: _busy || _ackBusy ? null : _continue,
                        child: const Text('Profilimi açmayı tekrar dene'),
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center),
                  ],
                  if (_ackFailed)
                    TextButton(
                      onPressed: _ackBusy
                          ? null
                          : () => _finishDecision(retryAck: true),
                      child: const Text('Okundu bilgisini yeniden gönder'),
                    ),
                  if (!_promotionFailed)
                    TextButton(
                      onPressed: _busy ? null : _load,
                      child: Text(
                        _error == null ? 'Durumu yenile' : 'Tekrar dene',
                      ),
                    ),
                  if (detail != null && detail.status != 'APPROVED')
                    TextButton.icon(
                      onPressed: _support,
                      icon: const Icon(Icons.support_agent),
                      label: const Text('WhatsApp ile destek al'),
                    ),
                  if (_session.isVenueApplicationSession && _push != null)
                    TextButton(
                      onPressed: _busy ? null : () => _push.requestPermission(),
                      child: const Text('Sonuç bildirimlerini aç'),
                    ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (!_current) return;
                            await _sessions.logout();
                          },
                    child: const Text('Çıkış yap'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
