import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/auth/auth_session.dart';
import '../../../../core/auth/auth_session_manager.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../../profile/presentation/share/event_share_flow.dart';
import '../../domain/event_audience_repository.dart';
import '../event_audience_controller.dart';
import '../event_audience_profile_draft.dart';

typedef AudienceExternalShare =
    Future<void> Function(EventAudienceStatus status);
typedef AudienceProfileShare =
    Future<void> Function(AuthSession expectedSession);

AuthSessionManager? _sessions(AuthSessionManager? value) =>
    value ??
    (serviceLocator.isRegistered<AuthSessionManager>()
        ? serviceLocator<AuthSessionManager>()
        : null);
EventAudienceRepository? _repository(EventAudienceRepository? value) =>
    value ??
    (serviceLocator.isRegistered<EventAudienceRepository>()
        ? serviceLocator<EventAudienceRepository>()
        : null);

/// Post rows read private state on tap; subsequent navigation and confirmation
/// belongs to the host route after the selection sheet has completely closed.
Future<void> showEventAudienceSheet(
  BuildContext context, {
  required String eventId,
  required String eventTitle,
  EventAudienceState? initialIntent,
  EventAudienceRepository? repository,
  AuthSessionManager? sessions,
  ValueChanged<EventAudienceState>? onChanged,
  AudienceExternalShare? onExternalShare,
  AudienceProfileShare? onProfileShare,
}) async {
  final manager = _sessions(sessions);
  final source = _repository(repository);
  if (manager == null ||
      source == null ||
      !context.mounted ||
      !canUseEventAudience(manager.session) ||
      ModalRoute.of(context)?.isCurrent != true) {
    return;
  }
  final expected = manager.session;
  final controller = EventAudienceController(
    eventId: eventId,
    repository: source,
    sessions: manager,
    initialIntent: initialIntent,
  );
  var noticeOwnsController = false;
  try {
    while (context.mounted && _valid(context, controller, expected)) {
      final action = await _managementSheet(context, controller, eventTitle);
      if (!context.mounted ||
          !_valid(context, controller, expected) ||
          action == null) {
        return;
      }
      await _performAction(
        context,
        controller,
        expected,
        action,
        onChanged: onChanged,
        onExternalShare: onExternalShare,
        onProfileShare: onProfileShare,
        onSaved: (value) {
          noticeOwnsController = true;
          _AudienceNotice(
            context: context,
            controller: controller,
            expected: expected,
            value: value,
            onProfileShare: onProfileShare,
            onClosed: () => scheduleMicrotask(controller.dispose),
          ).show();
        },
      );
      if (!context.mounted ||
          !_valid(context, controller, expected) ||
          !controller.needsRefresh ||
          (action.kind != _AudienceActionKind.choose &&
              action.kind != _AudienceActionKind.unpublish)) {
        break;
      }
      // Keep a failed/ambiguous row action recoverable. The sheet exposes a GET
      // reload first; no mutation is replayed or rebased automatically.
    }
  } finally {
    if (!noticeOwnsController) controller.dispose();
  }
}

class EventAudienceControls extends StatefulWidget {
  const EventAudienceControls({
    super.key,
    required this.eventId,
    required this.eventTitle,
    this.initialIntent,
    this.repository,
    this.sessions,
    this.onChanged,
    this.onExternalShare,
    this.onProfileShare,
    this.padding = EdgeInsets.zero,
    this.endedNoticeBuilder,
  });
  final String eventId;
  final String eventTitle;
  final EventAudienceState? initialIntent;
  final EventAudienceRepository? repository;
  final AuthSessionManager? sessions;
  final ValueChanged<EventAudienceState>? onChanged;
  final AudienceExternalShare? onExternalShare;
  final AudienceProfileShare? onProfileShare;
  final EdgeInsetsGeometry padding;

  /// Optional presentation only. Eligibility continues to come from server state.
  final WidgetBuilder? endedNoticeBuilder;
  @override
  State<EventAudienceControls> createState() => _EventAudienceControlsState();
}

class _EventAudienceControlsState extends State<EventAudienceControls> {
  EventAudienceController? _controller;
  bool _opening = false;
  int _flowEpoch = 0;
  ModalRoute<dynamic>? _optionsRoute;
  AuthSession? _flowSession;
  _AudienceNotice? _notice;

  void _bind() {
    final repository = _repository(widget.repository);
    final sessions = _sessions(widget.sessions);
    if (repository == null ||
        sessions == null ||
        widget.eventId.trim().isEmpty) {
      return;
    }
    _controller = EventAudienceController(
      eventId: widget.eventId.trim(),
      repository: repository,
      sessions: sessions,
      initialIntent: widget.initialIntent,
    )..addListener(_changed);
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _dismissOptions() {
    final route = _optionsRoute;
    if (route?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route?.isActive == true) route!.navigator?.removeRoute(route);
      });
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_flowSession != null &&
        _controller?.sameSession(_flowSession!) != true) {
      _flowEpoch++;
      _opening = false;
      _flowSession = null;
      _dismissOptions();
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant EventAudienceControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.repository != widget.repository ||
        oldWidget.sessions != widget.sessions) {
      _flowEpoch++;
      _opening = false;
      _flowSession = null;
      _notice?.close();
      _dismissOptions();
      _controller?.removeListener(_changed);
      _controller?.dispose();
      _controller = null;
      _bind();
    }
  }

  @override
  void dispose() {
    _notice?.close();
    _dismissOptions();
    _controller?.removeListener(_changed);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _choose(
    EventAudienceStatus intent,
    int revision,
    EventAudienceController expectedController, {
    required BuildContext anchorContext,
  }) async {
    final controller = _controller;
    if (!mounted ||
        controller == null ||
        !identical(controller, expectedController) ||
        _opening ||
        controller.busy ||
        controller.needsRefresh ||
        controller.revision != revision ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final expected = controller.session;
    final epoch = ++_flowEpoch;
    _opening = true;
    _flowSession = expected;
    _notice?.close();
    try {
      final _AudienceAction? action;
      if (intent != EventAudienceStatus.none &&
          controller.state?.intent == intent) {
        action = await _quickActionsMenu(
          context,
          anchorContext,
          controller,
          onRoute: (route) {
            if (epoch == _flowEpoch && identical(controller, _controller)) {
              _optionsRoute = route;
            }
          },
        );
        if (epoch == _flowEpoch) _optionsRoute = null;
      } else {
        action = _AudienceAction(
          _AudienceActionKind.choose,
          revision,
          intent: intent,
        );
      }
      if (!mounted ||
          !identical(controller, _controller) ||
          action == null ||
          !_valid(context, controller, expected)) {
        return;
      }
      await _performAction(
        context,
        controller,
        expected,
        action,
        onChanged: widget.onChanged,
        onExternalShare: widget.onExternalShare,
        onProfileShare: widget.onProfileShare,
        onSaved: (value) {
          if (!mounted || !identical(controller, _controller)) return;
          _notice = _AudienceNotice(
            context: context,
            controller: controller,
            expected: expected,
            value: value,
            onProfileShare: widget.onProfileShare,
          )..show();
        },
      );
    } finally {
      if (epoch == _flowEpoch) {
        _opening = false;
        _flowSession = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.allowed) {
      return const SizedBox.shrink();
    }
    final value = controller.state;
    final revision = controller.revision;
    return Padding(
      padding: widget.padding,
      child: Column(
        key: const Key('event-audience-controls'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.loading && value == null)
            const LinearProgressIndicator(key: Key('event-audience-loading'))
          else if (value != null) ...[
            if (value.canSetIntent || value.intent != EventAudienceStatus.none)
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 330 ||
                      MediaQuery.textScalerOf(context).scale(14) > 19;
                  Widget choice(EventAudienceStatus status, IconData icon) =>
                      Builder(
                        builder: (anchorContext) => Semantics(
                          button: true,
                          selected: value.intent == status,
                          label: status.label,
                          child: GradientOutlineButton(
                            key: Key('event-audience-${status.name}'),
                            label: status.label,
                            maxLines: 3,
                            horizontalPadding: 14,
                            leading: BrandGradientIcon.social(
                              value.intent == status
                                  ? Icons.check_circle_outline
                                  : icon,
                              size: 19,
                            ),
                            backgroundColor: value.intent == status
                                ? AppColors.socialPurple.withValues(alpha: .12)
                                : null,
                            onPressed:
                                controller.busy || controller.needsRefresh
                                ? null
                                : () => _choose(
                                    status,
                                    revision,
                                    controller,
                                    anchorContext: anchorContext,
                                  ),
                          ),
                        ),
                      );
                  final going = choice(
                    EventAudienceStatus.going,
                    Icons.event_available_outlined,
                  );
                  final thinking = choice(
                    EventAudienceStatus.thinking,
                    Icons.bookmark_border_rounded,
                  );
                  // Keep the existing choice removable after the event ends,
                  // without restoring the redundant summary/management row.
                  if (!value.canSetIntent) {
                    return value.intent == EventAudienceStatus.going
                        ? going
                        : thinking;
                  }
                  return stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            going,
                            const SizedBox(height: 8),
                            thinking,
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: going),
                            const SizedBox(width: 10),
                            Expanded(child: thinking),
                          ],
                        );
                },
              ),
            if (!value.canSetIntent)
              if (value.eventEnded && widget.endedNoticeBuilder != null)
                Padding(
                  padding: EdgeInsets.only(
                    top: value.intent == EventAudienceStatus.none ? 0 : 10,
                  ),
                  child: widget.endedNoticeBuilder!(context),
                )
              else
                Text(
                  value.eventEnded
                      ? 'Bu etkinlik sona erdi.'
                      : 'Etkinlik şu anda kullanılamıyor.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
          ],
          if (controller.error != null) ...[
            const SizedBox(height: 8),
            Text(controller.error!, key: const Key('event-audience-error')),
            TextButton(
              onPressed: controller.busy ? null : controller.refresh,
              child: const Text('Yeniden yükle'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _AudienceActionKind { choose, profile, external, unpublish }

/// Repeat taps on a detail-page choice need only contextual actions. The full
/// plan manager remains available from profile posts, where there are no choice
/// buttons outside its sheet.
Future<_AudienceAction?> _quickActionsMenu(
  BuildContext context,
  BuildContext anchorContext,
  EventAudienceController controller, {
  ValueChanged<ModalRoute<dynamic>?>? onRoute,
}) async {
  final expected = controller.session;
  final revision = controller.revision;
  final value = controller.state;
  if (!anchorContext.mounted ||
      value == null ||
      !_valid(context, controller, expected)) {
    return null;
  }
  final overlay = Navigator.of(context).overlay?.context.findRenderObject();
  final anchor = anchorContext.findRenderObject();
  if (overlay is! RenderBox ||
      anchor is! RenderBox ||
      !anchor.hasSize ||
      !overlay.hasSize) {
    return null;
  }
  RelativeRect position() {
    final offset = anchor.localToGlobal(Offset.zero, ancestor: overlay);
    return RelativeRect.fromRect(
      Rect.fromLTWH(
        offset.dx,
        offset.dy + anchor.size.height + 6,
        anchor.size.width,
        0,
      ),
      Offset.zero & overlay.size,
    );
  }

  var lastPosition = position();
  final scheme = Theme.of(context).colorScheme;
  ModalRoute<dynamic>? route;
  var selected = false;
  var dismissScheduled = false;
  void dismiss() {
    if (dismissScheduled) return;
    dismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive == true) route!.navigator?.removeRoute(route!);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void changed() {
    if (context.mounted &&
        anchorContext.mounted &&
        controller.sameSession(expected) &&
        controller.revision == revision) {
      return;
    }
    dismiss();
  }

  PopupMenuEntry<_AudienceAction> item({
    required String key,
    required String label,
    required IconData icon,
    required _AudienceAction action,
    bool captureRoute = false,
  }) => _AudienceQuickMenuItem(
    key: Key(key),
    value: action,
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    canSelect: (itemContext) {
      if (selected ||
          !context.mounted ||
          !anchorContext.mounted ||
          !anchor.attached ||
          !_valid(itemContext, controller, expected) ||
          controller.busy ||
          controller.needsRefresh ||
          controller.revision != revision) {
        return false;
      }
      selected = true;
      return true;
    },
    child: Builder(
      key: captureRoute ? const Key('event-audience-quick-menu') : null,
      builder: (itemContext) {
        route = ModalRoute.of(itemContext);
        onRoute?.call(route);
        changed();
        return Row(
          children: [
            BrandGradientIcon.social(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  controller.addListener(changed);
  try {
    final result = await showMenu<_AudienceAction>(
      context: context,
      semanticLabel: 'Etkinlik seçimi',
      positionBuilder: (_, _) {
        if (anchorContext.mounted &&
            anchor.attached &&
            anchor.hasSize &&
            overlay.attached &&
            overlay.hasSize) {
          lastPosition = position();
        } else {
          dismiss();
        }
        return lastPosition;
      },
      constraints: const BoxConstraints(minWidth: 224, maxWidth: 280),
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      color: scheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: .24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: .12)),
      ),
      items: [
        item(
          key: 'event-audience-quick-clear',
          label: 'Seçimimi kaldır',
          icon: Icons.close_rounded,
          action: _AudienceAction(
            _AudienceActionKind.choose,
            revision,
            intent: EventAudienceStatus.none,
          ),
          captureRoute: true,
        ),
        if (value.canPublish && canPublishAudienceProfile(expected))
          item(
            key: 'event-audience-quick-profile',
            label: value.publishedOnProfile
                ? 'Paylaşımı düzenle'
                : 'Profilinde paylaş',
            icon: Icons.person_outline_rounded,
            action: _AudienceAction(_AudienceActionKind.profile, revision),
          ),
      ],
    );
    await route?.completed;
    return result;
  } finally {
    controller.removeListener(changed);
  }
}

class _AudienceQuickMenuItem extends PopupMenuItem<_AudienceAction> {
  const _AudienceQuickMenuItem({
    super.key,
    required super.value,
    required super.child,
    required super.height,
    required super.padding,
    required this.canSelect,
  });
  final bool Function(BuildContext context) canSelect;

  @override
  PopupMenuItemState<_AudienceAction, _AudienceQuickMenuItem> createState() =>
      _AudienceQuickMenuItemState();
}

class _AudienceQuickMenuItemState
    extends PopupMenuItemState<_AudienceAction, _AudienceQuickMenuItem> {
  @override
  void handleTap() {
    if (mounted && widget.canSelect(context)) super.handleTap();
  }
}

class _AudienceAction {
  const _AudienceAction(this.kind, this.revision, {this.intent});
  final _AudienceActionKind kind;
  final int revision;
  final EventAudienceStatus? intent;
}

bool _valid(
  BuildContext context,
  EventAudienceController controller,
  AuthSession expected,
) =>
    context.mounted &&
    controller.sameSession(expected) &&
    ModalRoute.of(context)?.isCurrent == true;

Future<void> _performAction(
  BuildContext context,
  EventAudienceController controller,
  AuthSession expected,
  _AudienceAction action, {
  ValueChanged<EventAudienceState>? onChanged,
  AudienceExternalShare? onExternalShare,
  AudienceProfileShare? onProfileShare,
  required ValueChanged<EventAudienceState> onSaved,
}) async {
  if (!_valid(context, controller, expected) ||
      controller.busy ||
      controller.needsRefresh ||
      controller.revision != action.revision) {
    return;
  }
  final current = controller.state;
  if (current == null) return;
  switch (action.kind) {
    case _AudienceActionKind.choose:
      if (action.intent == current.intent) return;
      final value = await controller.choose(
        action.intent!,
        expectedRevision: action.revision,
      );
      if (!context.mounted ||
          !_valid(context, controller, expected) ||
          value == null) {
        return;
      }
      onChanged?.call(value);
      if (context.mounted &&
          _valid(context, controller, expected) &&
          value.intent != EventAudienceStatus.none) {
        onSaved(value);
      }
    case _AudienceActionKind.unpublish:
      final value = await controller.unpublish(
        expectedRevision: action.revision,
      );
      if (context.mounted &&
          _valid(context, controller, expected) &&
          value != null) {
        onChanged?.call(value);
      }
    case _AudienceActionKind.profile:
      if (!current.canPublish || !canPublishAudienceProfile(expected)) return;
      if (onProfileShare != null) {
        await onProfileShare(expected);
      } else {
        await openEventAudienceProfileDraft(
          context,
          eventId: controller.eventId,
          expectedSession: expected,
          sessions: controller.sessions,
        );
      }
    case _AudienceActionKind.external:
      if (current.intent == EventAudienceStatus.none ||
          current.eventEnded ||
          !current.eventAvailable) {
        return;
      }
      if (onExternalShare != null) {
        await onExternalShare(current.intent);
      } else {
        await shareAudienceEvent(
          context,
          eventId: controller.eventId,
          status: current.intent,
          sessions: controller.sessions,
          expectedSession: expected,
          audienceRepository: controller.repository,
        );
      }
  }
}

Future<_AudienceAction?> _managementSheet(
  BuildContext context,
  EventAudienceController controller,
  String title, {
  ValueChanged<ModalRoute<dynamic>?>? onRoute,
}) async {
  final expected = controller.session;
  ModalRoute<dynamic>? route;
  void changed() {
    if (controller.sameSession(expected)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (route?.isActive == true) route!.navigator?.removeRoute(route!);
    });
  }

  controller.addListener(changed);
  try {
    final action = await showModalBottomSheet<_AudienceAction>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.navBlueDeep,
      builder: (sheetContext) {
        route = ModalRoute.of(sheetContext);
        onRoute?.call(route);
        return _AudienceManagementSheet(
          controller: controller,
          expected: expected,
          title: title,
        );
      },
    );
    await route?.completed;
    return action;
  } finally {
    controller.removeListener(changed);
  }
}

class _AudienceManagementSheet extends StatefulWidget {
  const _AudienceManagementSheet({
    required this.controller,
    required this.expected,
    required this.title,
  });
  final EventAudienceController controller;
  final AuthSession expected;
  final String title;
  @override
  State<_AudienceManagementSheet> createState() =>
      _AudienceManagementSheetState();
}

class _AudienceManagementSheetState extends State<_AudienceManagementSheet> {
  bool _finished = false;
  void _close([_AudienceAction? action]) {
    if (_finished ||
        !_valid(context, widget.controller, widget.expected) ||
        widget.controller.busy ||
        (action != null && action.revision != widget.controller.revision)) {
      return;
    }
    _finished = true;
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      if (!controller.sameSession(widget.expected)) {
        return const SizedBox.shrink();
      }
      final value = controller.state;
      final revision = controller.revision;
      final enabled = !controller.busy && !controller.needsRefresh;
      Widget action(
        String key,
        String label,
        IconData icon,
        _AudienceActionKind kind, {
        EventAudienceStatus? intent,
      }) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: GradientOutlineButton(
          key: Key(key),
          label: label,
          maxLines: 3,
          leading: BrandGradientIcon.social(icon, size: 20),
          onPressed: enabled
              ? () => _close(_AudienceAction(kind, revision, intent: intent))
              : null,
        ),
      );
      return SingleChildScrollView(
        key: const Key('event-audience-management'),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (value == null && controller.loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: LinearProgressIndicator(),
              ),
            if (value != null) ...[
              const SizedBox(height: 8),
              Text(
                value.intent == EventAudienceStatus.none
                    ? 'Etkinlik seçimin'
                    : 'Seçimin: ${value.intent.label}',
                style: TextStyle(color: AppColors.textMuted),
              ),
              if (value.canSetIntent)
                for (final status in [
                  EventAudienceStatus.going,
                  EventAudienceStatus.thinking,
                ])
                  action(
                    'event-audience-management-${status.name}',
                    status.label,
                    value.intent == status
                        ? Icons.check_circle_outline
                        : Icons.event_available_outlined,
                    _AudienceActionKind.choose,
                    intent: status,
                  ),
              if (value.intent != EventAudienceStatus.none) ...[
                if (value.canPublish &&
                    canPublishAudienceProfile(widget.expected))
                  action(
                    'event-audience-profile-share',
                    value.publishedOnProfile
                        ? 'Paylaşımı düzenle'
                        : 'Profilinde paylaş',
                    Icons.person_outline_rounded,
                    _AudienceActionKind.profile,
                  ),
                if (!value.eventEnded && value.eventAvailable)
                  action(
                    'event-audience-external-share',
                    'Diğer uygulamalarda paylaş',
                    Icons.ios_share_outlined,
                    _AudienceActionKind.external,
                  ),
                if (value.publishedOnProfile)
                  TextButton(
                    key: const Key('event-audience-unpublish'),
                    onPressed: enabled
                        ? () => _close(
                            _AudienceAction(
                              _AudienceActionKind.unpublish,
                              revision,
                            ),
                          )
                        : null,
                    child: const Text('Profil paylaşımını kaldır'),
                  ),
                TextButton(
                  key: const Key('event-audience-clear'),
                  onPressed: enabled
                      ? () => _close(
                          _AudienceAction(
                            _AudienceActionKind.choose,
                            revision,
                            intent: EventAudienceStatus.none,
                          ),
                        )
                      : null,
                  child: const Text('Seçimimi kaldır'),
                ),
              ],
              if (!value.canSetIntent)
                Text(
                  value.eventEnded
                      ? 'Bu etkinlik sona erdi.'
                      : 'Etkinlik şu anda kullanılamıyor.',
                ),
            ],
            if (controller.error != null) ...[
              const SizedBox(height: 12),
              Text(controller.error!),
              TextButton(
                onPressed: controller.busy ? null : controller.refresh,
                child: const Text('Yeniden yükle'),
              ),
            ],
            TextButton(
              key: const Key('event-audience-management-dismiss'),
              onPressed: controller.busy ? null : () => _close(),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    },
  );
}

/// New confirmed selections replace transient feedback; lifecycle cleanup removes
/// only this feature's own visible snackbar, never another feature's notification.
class _AudienceNotice {
  _AudienceNotice({
    required this.context,
    required this.controller,
    required this.expected,
    required this.value,
    this.onProfileShare,
    this.onClosed,
  }) : revision = controller.revision;
  final BuildContext context;
  final EventAudienceController controller;
  final AuthSession expected;
  final EventAudienceState value;
  final int revision;
  final AudienceProfileShare? onProfileShare;
  final VoidCallback? onClosed;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _bar;
  bool _barClosed = true;
  ScaffoldMessengerState? _messenger;
  bool _finished = false;
  bool _actionTaken = false;
  bool get valid =>
      !_finished &&
      _valid(context, controller, expected) &&
      !controller.busy &&
      !controller.needsRefresh &&
      controller.revision == revision &&
      controller.state?.intent == value.intent &&
      controller.state?.version == value.version;

  void show() {
    if (!valid) {
      _finish();
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      _finish();
      return;
    }
    _messenger = messenger;
    controller.addListener(_changed);
    ModalRoute.of(context)?.popped.then((_) => close());
    final mayPublish = value.canPublish && canPublishAudienceProfile(expected);
    messenger.clearSnackBars();
    messenger.removeCurrentSnackBar();
    final bar = messenger.showSnackBar(
      appSnackBar(
        context,
        content: Text('${value.intent.label} olarak işaretlendi.'),
        tone: AppSnackBarTone.success,
        duration: const Duration(seconds: 8),
        persist: false,
        inlineAction: true,
        action: mayPublish
            ? SnackBarAction(
                key: const Key('event-audience-snackbar-profile'),
                label: value.publishedOnProfile
                    ? 'Paylaşımı düzenle'
                    : 'Profilinde paylaş',
                onPressed: () {
                  if (!valid ||
                      _actionTaken ||
                      controller.state?.canPublish != true) {
                    return;
                  }
                  _actionTaken = true;
                  if (onProfileShare != null) {
                    unawaited(onProfileShare!(expected));
                  } else {
                    unawaited(
                      openEventAudienceProfileDraft(
                        context,
                        eventId: controller.eventId,
                        expectedSession: expected,
                        sessions: controller.sessions,
                      ),
                    );
                  }
                },
              )
            : null,
      ),
    );
    _bar = bar;
    _barClosed = false;
    bar.closed.then((_) {
      _barClosed = true;
      _finish();
    });
  }

  void _changed() {
    if (!valid) close();
  }

  void close() {
    if (_finished) return;
    final messenger = _messenger;
    _finish();
    // ScaffoldMessenger shares snackbar content across mounted route Scaffolds.
    // A GlobalKey in that content reparents it during layout and is not safe.
    // This notice is shown immediately, never queued. Its native completion
    // releases ownership. Wait past the frame AND its completion microtasks so
    // replacement feedback cannot be dismissed by a stale cleanup callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messenger?.mounted != true || _barClosed) return;
      Timer.run(() {
        if (messenger?.mounted == true && !_barClosed) _bar?.close();
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    controller.removeListener(_changed);
    onClosed?.call();
  }
}
