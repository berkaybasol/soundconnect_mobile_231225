import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import '../../domain/entities/event_performer_request.dart';
import 'event_performer_request_copy.dart';

/// Read-only help: opening/dismissing this never changes either permission.
class EventCalendarVisibilityHelp extends StatefulWidget {
  const EventCalendarVisibilityHelp({
    super.key,
    required this.request,
    this.enabled = true,
    this.iconOnly = false,
  });

  final EventPerformerRequest request;
  final bool enabled;
  final bool iconOnly;

  @override
  State<EventCalendarVisibilityHelp> createState() =>
      _EventCalendarVisibilityHelpState();
}

class _EventCalendarVisibilityHelpState
    extends State<EventCalendarVisibilityHelp> {
  DialogRoute<void>? _dialog;
  NavigatorState? _navigator;

  void _removeOwnedDialog() {
    final dialog = _dialog;
    final navigator = _navigator;
    _dialog = null;
    _navigator = null;
    if (dialog == null || navigator == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator.mounted && dialog.isActive) navigator.removeRoute(dialog);
    });
  }

  @override
  void didUpdateWidget(covariant EventCalendarVisibilityHelp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.requestId != widget.request.requestId ||
        oldWidget.request.targetId != widget.request.targetId ||
        oldWidget.request.targetType != widget.request.targetType ||
        oldWidget.request.requestPurpose != widget.request.requestPurpose) {
      _removeOwnedDialog();
    }
  }

  @override
  void dispose() {
    _removeOwnedDialog();
    super.dispose();
  }

  Future<void> _showHelp() async {
    if (!mounted ||
        !widget.enabled ||
        _dialog != null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final request = widget.request;
    final navigator = Navigator.of(context, rootNavigator: true);
    var dismissed = false;
    late final DialogRoute<void> route;
    route = DialogRoute<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        final paragraphs = request.calendarVisibilityHelpParagraphs;
        void dismiss() {
          if (dismissed || !dialogContext.mounted || !route.isCurrent) return;
          dismissed = true;
          Navigator.of(dialogContext).pop();
        }

        return Dialog(
          key: const Key('event-calendar-visibility-help-dialog'),
          backgroundColor: scheme.surfaceContainerHighest,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      Icons.calendar_month_outlined,
                      size: 28,
                      color: AppColors.brandGradient[1],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    request.calendarVisibilityHelpTitle,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  for (var index = 0; index < paragraphs.length; index++) ...[
                    const SizedBox(height: 16),
                    if (index == 1)
                      _VisibilityNotice(text: paragraphs[index])
                    else
                      Text(
                        paragraphs[index],
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: GradientOutlineButton(
                      key: const Key('event-calendar-visibility-help-dismiss'),
                      label: 'Anladım',
                      strokeWidth: .8,
                      onPressed: dismiss,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _dialog = route;
    _navigator = navigator;
    try {
      await navigator.push(route);
    } finally {
      if (identical(_dialog, route)) {
        _dialog = null;
        _navigator = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.iconOnly) {
      return Tooltip(
        message: 'Profilde gösterim hakkında bilgi',
        child: Semantics(
          button: true,
          enabled: widget.enabled,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key(
                'event-calendar-visibility-help-${widget.request.requestId}',
              ),
              borderRadius: BorderRadius.circular(24),
              onTap: widget.enabled ? _showHelp : null,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: widget.enabled
                      ? const BrandGradientIcon(
                          Icons.info_outline_rounded,
                          size: 20,
                        )
                      : Icon(
                          Icons.info_outline_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key(
            'event-calendar-visibility-help-${widget.request.requestId}',
          ),
          onTap: widget.enabled ? _showHelp : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.calendar_month_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.request.calendarVisibilityExplanation,
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Detaylar için dokun',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brandGradient[1],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
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

class _VisibilityNotice extends StatelessWidget {
  const _VisibilityNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('event-calendar-visibility-notice'),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(.8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(15.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: ExcludeSemantics(
                    child: BrandGradientIcon(
                      Icons.info_outline_rounded,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
