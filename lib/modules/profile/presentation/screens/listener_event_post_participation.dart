import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../event_audience/domain/event_audience_repository.dart';
import '../../../event_audience/presentation/event_audience_controller.dart';

/// The viewer's private plan is independent of the publication author's plan.
class ListenerEventPostParticipation extends StatefulWidget {
  const ListenerEventPostParticipation({
    super.key,
    required this.eventId,
    required this.refreshKey,
    required this.repository,
    required this.sessions,
    required this.canInteract,
    required this.onError,
    required this.builder,
  });

  final String eventId;
  final Object refreshKey;
  final EventAudienceRepository repository;
  final AuthSessionManager sessions;
  final bool Function() canInteract;
  final ValueChanged<String> onError;
  final Widget Function(bool going, bool busy, VoidCallback? onToggle) builder;

  @override
  State<ListenerEventPostParticipation> createState() =>
      _ListenerEventPostParticipationState();
}

class _ListenerEventPostParticipationState
    extends State<ListenerEventPostParticipation> {
  late EventAudienceController _controller;
  late AuthSession _session;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _session = widget.sessions.session;
    _controller = EventAudienceController(
      eventId: widget.eventId,
      repository: widget.repository,
      sessions: widget.sessions,
    );
  }

  @override
  void didUpdateWidget(covariant ListenerEventPostParticipation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.refreshKey != widget.refreshKey ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.sessions, widget.sessions)) {
      _controller.dispose();
      _bind();
    }
  }

  bool _current(EventAudienceController controller) =>
      mounted &&
      identical(_controller, controller) &&
      controller.sameSession(_session) &&
      widget.canInteract();

  Future<void> _toggle(
    EventAudienceController controller,
    bool Function() canInteract,
  ) async {
    bool current() => _current(controller) && canInteract();
    if (!current() || controller.busy) return;
    // Retry an unread/uncertain state before deciding which mutation is safe.
    if (controller.needsRefresh || controller.state == null) {
      await controller.refresh();
      if (current() && controller.error != null) {
        widget.onError(controller.error!);
      }
      return;
    }
    final target = controller.state!.intent == EventAudienceStatus.going
        ? EventAudienceStatus.none
        : EventAudienceStatus.going;
    await controller.choose(target, expectedRevision: controller.revision);
    if (current() && controller.error != null) {
      widget.onError(controller.error!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final controller = _controller;
      final canInteract = widget.canInteract;
      final going = _controller.state?.intent == EventAudienceStatus.going;
      final available =
          _current(_controller) &&
          (going ||
              _controller.state == null ||
              _controller.needsRefresh ||
              _controller.state!.canSetIntent);
      return widget.builder(
        going,
        _controller.busy && available,
        available && !_controller.busy
            ? () => unawaited(_toggle(controller, canInteract))
            : null,
      );
    },
  );
}
