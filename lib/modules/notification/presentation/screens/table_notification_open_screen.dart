import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/push/push_provider.dart';
import '../../../../core/di/service_locator.dart';
import '../../data/notification_target_repository.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/table_notification_target.dart';
import '../../../tablegroup/presentation/screens/table_group_detail_screen.dart';
import '../../../tablegroup/presentation/screens/table_group_list_screen.dart';
import '../cubit/notification_cubit.dart';
import '../notification_direct_open.dart';
import '../notification_target_read.dart';

/// Shared inbox/native TABLE entry; fresh owned resolution is the only target proof.
class TableNotificationOpenScreen extends StatefulWidget {
  const TableNotificationOpenScreen({super.key, required this.notification});
  TableNotificationOpenScreen.native({super.key, required PushTarget target})
    : notification = AppNotification(
        id: target.notificationId,
        recipientId: target.recipientId,
        type: target.type,
        title: '',
        message: '',
        read: false,
        createdAt: null,
        payload: const {},
      );
  final AppNotification notification;
  @override
  State<TableNotificationOpenScreen> createState() =>
      _TableNotificationOpenScreenState();
}

class _TableNotificationOpenScreenState
    extends State<TableNotificationOpenScreen>
    with WidgetsBindingObserver, RouteAware {
  late final _sessions = serviceLocator<AuthSessionManager>();
  late final _session = _sessions.session;
  late final _repository = serviceLocator<NotificationTargetRepository>();
  ModalRoute<dynamic>? _route;
  bool _initial = true, _scheduled = false, _busy = false;
  bool _deferredFailure = false;
  int _generation = 0;
  TableNotificationTarget? _closedTarget;
  NotificationTargetRead? _closedTicket;
  bool get _sessionCurrent =>
      identical(_sessions.session, _session) &&
      _session.isAuthenticated &&
      _session.isActive &&
      !_session.isVenueApplicationSession &&
      !_session.requiresListenerProfileChoice &&
      _session.expiresAt?.isAfter(DateTime.now()) == true &&
      _session.userId == widget.notification.recipientId;
  bool get _visible =>
      mounted &&
      _sessionCurrent &&
      _route?.isCurrent == true &&
      _route?.isActive == true &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed);

  @override
  void initState() {
    super.initState();
    _session;
    _sessions.addListener(_sessionChanged);
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = NotificationDirectOpen.routeOf(context);
    if (!identical(r, _route)) {
      notificationTargetRouteObserver.unsubscribe(this);
      _route = r;
      if (r != null) notificationTargetRouteObserver.subscribe(this, r);
    }
  }

  @override
  void didUpdateWidget(covariant TableNotificationOpenScreen old) {
    super.didUpdateWidget(old);
    if (old.notification.id != widget.notification.id ||
        old.notification.recipientId != widget.notification.recipientId ||
        old.notification.type != widget.notification.type) {
      _generation++;
      _busy = false;
      _deferredFailure = false;
      _initial = true;
      _closedTarget = null;
      _closedTicket = null;
      _schedule();
    }
  }

  void _sessionChanged() {
    if (!mounted || _sessionCurrent) return;
    _generation++;
    _busy = false;
    _deferredFailure = false;
  }

  @override
  void didPopNext() => _schedule();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  void _schedule() {
    if (!mounted || (!_initial && !_deferredFailure) || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!_visible) return;
      if (_deferredFailure) {
        _deferredFailure = false;
        _showUnavailable();
      } else if (_initial) {
        unawaited(_open());
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _open() async {
    if (!_visible || _busy) return;
    _initial = false;
    _deferredFailure = false;
    final generation = ++_generation;
    _busy = true;
    try {
      final response = await _repository.resolveTable(
        widget.notification,
        _session,
      );
      if (!mounted || generation != _generation) return;
      if (!_visible) {
        _deferUnavailable();
        return;
      }
      if (!response.isSuccess || response.data == null) {
        _showUnavailable();
        return;
      }
      final target = response.data!;
      if (target.result && target.tableStatus != 'ACTIVE') {
        final ticket = NotificationTargetRead.table(
          notification: target.notification,
          cubit: serviceLocator<NotificationCubit>(),
          sessions: _sessions,
          repository: _repository,
          content: target,
        );
        setState(() {
          _closedTarget = target;
          _closedTicket = ticket;
        });
        return;
      }
      final route = MaterialPageRoute<void>(
        builder: (destinationContext) =>
            target.result && !_hasResultDetail(target)
            ? NotificationTerminalFeedback(
                message: _resultMessage(target),
                contentIdentity: target,
                child: TableGroupListScreen(),
              )
            : TableGroupDetailScreen(
                key: ObjectKey(target),
                args: TableGroupDetailArgs(
                  tableGroupId: target.tableGroupId,
                  openChat: !target.result,
                  notificationTarget: target.result ? null : target,
                  notificationResult: target.result ? target : null,
                  notificationResultMessage: target.result
                      ? _resultMessage(target)
                      : null,
                  onNotificationRetry: () => NotificationDirectOpen.start(
                    destinationContext,
                    identity: target.notification.id,
                    replaceOrigin: true,
                    builder: (_) => TableNotificationOpenScreen(
                      notification: target.notification,
                    ),
                  ),
                ),
              ),
      );
      NotificationTargetRead.table(
        notification: target.notification,
        cubit: serviceLocator<NotificationCubit>(),
        sessions: _sessions,
        repository: _repository,
        content: target,
      ).attach(route);
      NotificationDirectOpen.push(context, route);
    } catch (_) {
      if (mounted && generation == _generation) {
        if (_visible) {
          _showUnavailable();
        } else {
          _deferUnavailable();
        }
      }
    } finally {
      if (mounted && generation == _generation) _busy = false;
    }
  }

  // A response completed out of view cannot prove a fresh visible target.
  // Keep only explicit recovery intent; returning never reuses or refetches it.
  void _deferUnavailable() {
    _deferredFailure = _sessionCurrent && _route?.isActive == true;
  }

  void _showUnavailable() => NotificationDirectOpen.feedback(
    context,
    message: 'Bu masa şu anda açılamıyor.',
    retry: _open,
    isCurrent: () => _visible,
  );

  @override
  void dispose() {
    _generation++;
    _sessions.removeListener(_sessionChanged);
    notificationTargetRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = _closedTarget;
    final ticket = _closedTicket;
    if (target == null || ticket == null) return const SizedBox.shrink();
    return NotificationDirectOpen.terminalFeedback(
      context,
      ticket: ticket,
      message: target.tableStatus == 'CANCELLED'
          ? 'Bu masa kapatıldı.'
          : 'Bu masanın süresi doldu.',
      contentIdentity: target,
    );
  }

  // Normal table detail permits active public viewers, and closed-table owners
  // or accepted members. A historical ticket never opens the current pending
  // panel or chat: result details use the existing overview/archive instead.
  bool _hasResultDetail(TableNotificationTarget target) =>
      target.tableStatus == 'ACTIVE' ||
      target.event == 'JOIN_REQUEST_RECEIVED' ||
      target.event == 'PARTICIPANT_LEFT' ||
      (target.subjectId == target.notification.recipientId &&
          target.participantStatus == 'ACCEPTED');

  String _resultMessage(TableNotificationTarget target) =>
      switch (target.event) {
        'JOIN_REQUEST_RECEIVED' =>
          target.sameApplication
              ? 'Bu başvuru artık beklemiyor.'
              : 'Bu bildirim önceki masa başvurusuna ait.',
        'JOIN_REQUEST_APPROVED' =>
          target.sameApplication
              ? 'Bu masaya katılımın sona erdi.'
              : 'Bu bildirim önceki masa katılımına ait.',
        'JOIN_REQUEST_REJECTED' => 'Başvurun kabul edilmedi.',
        'PARTICIPANT_LEFT' => 'Bir katılımcı masadan ayrıldı.',
        'PARTICIPANT_REMOVED' => 'Bu masadan çıkarıldın.',
        'CANCELLED' =>
          target.reason == 'OWNER_JOINED_ANOTHER_TABLE'
              ? 'Masa sahibi başka bir masaya katıldığı için masa kapandı.'
              : 'Masa kapatıldı.',
        'EXPIRED' => 'Masanın süresi doldu.',
        _ => 'Bu masa artık kullanılamıyor.',
      };
}
