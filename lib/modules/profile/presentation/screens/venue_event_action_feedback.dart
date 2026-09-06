import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';

Future<bool> confirmVenueEventDeletion(
  BuildContext context,
  String title,
) async {
  var finished = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final scheme = theme.colorScheme;
      void finish(bool value) {
        if (finished || ModalRoute.of(dialogContext)?.isCurrent != true) return;
        finished = true;
        Navigator.of(dialogContext).pop(value);
      }

      return Dialog(
        key: const Key('venue-event-delete-dialog'),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: .12)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.coral,
                      size: 25,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Etkinlik silinsin mi?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '“$title” takvimden kalıcı olarak kaldırılacak. Bu işlem geri alınamaz.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 26),
                GradientOutlineButton(
                  key: const Key('venue-event-delete-confirm'),
                  label: 'Etkinliği sil',
                  strokeWidth: .8,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.coral,
                    size: 19,
                  ),
                  onPressed: () => finish(true),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('venue-event-delete-cancel'),
                  onPressed: () => finish(false),
                  child: Text(
                    'Vazgeç',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result == true;
}

void showVenueEventFeedback(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(20, 12, 20, 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: .12)),
        ),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? AppColors.coral : AppColors.brandGradient.last,
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: scheme.onSurface, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
}
