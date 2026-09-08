import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum AppSnackBarTone { success, error, warning, info }

/// The shared visual treatment for transient feedback, based on venue events.
/// Callers retain ownership of when feedback is shown, replaced and dismissed.
SnackBar appSnackBar(
  BuildContext context, {
  required Widget content,
  required AppSnackBarTone tone,
  Duration duration = const Duration(seconds: 4),
  SnackBarAction? action,
  bool? persist,
  bool inlineAction = false,
  EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(20, 12, 20, 18),
}) {
  final scheme = Theme.of(context).colorScheme;
  final (icon, color) = switch (tone) {
    AppSnackBarTone.success => (
      Icons.check_circle_outline_rounded,
      AppColors.brandGradient.last,
    ),
    AppSnackBarTone.error => (Icons.error_outline_rounded, AppColors.coral),
    AppSnackBarTone.warning => (
      Icons.warning_amber_rounded,
      scheme.brightness == Brightness.light
          ? const Color(0xFF956000)
          : AppColors.gradientB,
    ),
    AppSnackBarTone.info => (
      Icons.info_outline_rounded,
      scheme.onSurfaceVariant,
    ),
  };

  return SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: scheme.surfaceContainerHighest,
    elevation: 0,
    margin: margin,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: scheme.onSurface.withValues(alpha: .12)),
    ),
    duration: duration,
    // Match the native action's default lifetime even though its layout lives
    // in content. Native overflow rows reserve 40% of the message width and
    // can push the floating bar off screen at large accessibility text sizes.
    persist: persist ?? action != null,
    content: LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final resolvedMargin = margin.resolve(Directionality.of(context));
        var actionHeight = 0.0;
        var actionWidth = 0.0;
        if (action != null) {
          final painter = TextPainter(
            text: TextSpan(
              text: action.label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            textDirection: Directionality.of(context),
            textScaler: media.textScaler,
          )..layout(maxWidth: math.max(1, constraints.maxWidth - 32));
          actionHeight = math.max(48, painter.height + 16) + 8;
          actionWidth = math.min(
            constraints.maxWidth,
            painter.maxIntrinsicWidth + 32,
          );
          painter.dispose();
        }
        // Opt-in compact feedback can keep the action beside the message.
        // Larger text/narrow widths retain the original accessible second row.
        final useInlineAction =
            inlineAction &&
            action != null &&
            media.textScaler.scale(14) <= 18 &&
            constraints.maxWidth - actionWidth - 45 >= 105;
        if (useInlineAction) actionHeight = 0;
        final actionButton = action == null
            ? null
            : TextButtonTheme(
                data: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                child: SnackBarAction(
                  key: action.key,
                  label: action.label,
                  onPressed: action.onPressed,
                  textColor: scheme.onSurface,
                  disabledTextColor: scheme.onSurfaceVariant,
                  backgroundColor: action.backgroundColor,
                  disabledBackgroundColor: action.disabledBackgroundColor,
                ),
              );
        // Reserve space for the action and Scaffold's bottom controls. Only long
        // messages scroll; ordinary feedback keeps its natural height. Calculate
        // this at layout time so keyboard, rotation and custom composer margins
        // are reflected while persistent feedback is already visible.
        final availableHeight = math.max(
          0.0,
          media.size.height -
              media.viewInsets.bottom -
              media.viewPadding.vertical -
              resolvedMargin.vertical -
              30,
        );
        final maxMessageHeight = (availableHeight * .6 - actionHeight).clamp(
          24.0,
          240.0,
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxMessageHeight),
                    child: SingleChildScrollView(
                      primary: false,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: scheme.onSurface, height: 1.4),
                        child: content,
                      ),
                    ),
                  ),
                ),
                if (useInlineAction && actionButton != null) ...[
                  const SizedBox(width: 12),
                  SizedBox(width: actionWidth, child: actionButton),
                ],
              ],
            ),
            if (!useInlineAction && actionButton != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                // Keep the native once-only action and dismissal semantics.
                child: actionButton,
              ),
            ],
          ],
        );
      },
    ),
  );
}
