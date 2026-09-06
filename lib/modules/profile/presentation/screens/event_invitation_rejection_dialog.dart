import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/brand_gradient_icon.dart';
import '../../../../shared/widgets/gradient_outline_button.dart';

class EventInvitationRejectionDialog extends StatelessWidget {
  const EventInvitationRejectionDialog({
    super.key,
    required this.requestId,
    required this.onDecision,
  });

  final String requestId;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      key: const Key('event-invitation-rejection-dialog'),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          padding: const EdgeInsets.all(.8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: AppColors.brandGradient),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(23.2),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const ExcludeSemantics(
                        child: BrandGradientIcon(
                          Icons.event_busy_outlined,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    namesRoute: true,
                    child: Text(
                      'Etkinlik davetini reddetmek istiyor musunuz?',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 21,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  GradientOutlineButton(
                    key: Key('confirm-reject-$requestId'),
                    label: 'Reddet',
                    strokeWidth: .8,
                    onPressed: () => onDecision(true),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: Key('cancel-reject-$requestId'),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => onDecision(false),
                    child: const Text('Vazgeç'),
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
