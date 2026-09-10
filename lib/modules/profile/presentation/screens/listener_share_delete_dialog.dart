import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';
import 'listener_profile_theme.dart';

class ListenerShareDeleteDialog extends StatelessWidget {
  const ListenerShareDeleteDialog.event({super.key, required this.confirmKey})
    : message =
          'Bu paylaşım profilinden kaldırılacak ve paylaşıma ait yorumlar kapanacak.',
      detail = 'Etkinlik planın korunur.';

  const ListenerShareDeleteDialog.overthinking({
    super.key,
    required this.confirmKey,
  }) : message = 'Bu paylaşım profilinden kaldırılacak.',
       detail = 'Asıl yazı, beğeniler ve yorumlar korunur.';

  final Key confirmKey;
  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    void decide(bool confirmed) {
      if (context.mounted && route?.isCurrent == true) {
        navigator.pop(confirmed);
      }
    }

    return ListenerProfileTheme(
      child: Dialog(
        key: const Key('listener-share-delete-dialog'),
        backgroundColor: listenerProfileSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: listenerProfileBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.coral.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.coral.withValues(alpha: .14),
                      ),
                    ),
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 25,
                        color: AppColors.coral,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Semantics(
                  namesRoute: true,
                  header: true,
                  child: const Text(
                    'Paylaşımı kaldır?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: -.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: listenerProfileMuted,
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF151D2D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    detail,
                    style: const TextStyle(
                      color: listenerProfileMuted,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GradientOutlineButton(
                  key: confirmKey,
                  label: 'Paylaşımı kaldır',
                  maxLines: null,
                  horizontalPadding: 16,
                  strokeWidth: 1,
                  onPressed: () => decide(true),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => decide(false),
                  style: TextButton.styleFrom(
                    foregroundColor: listenerProfileMuted,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Vazgeç'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
