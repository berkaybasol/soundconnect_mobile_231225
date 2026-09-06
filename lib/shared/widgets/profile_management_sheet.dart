import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProfileManagementSheetOption<T extends Object> {
  const ProfileManagementSheetOption({
    required this.value,
    required this.icon,
    required this.label,
    this.key,
  });
  final T value;
  final IconData icon;
  final String label;
  final Key? key;
}

final _activeManagementSheets = Expando<bool>();

Future<T?> showProfileManagementSheet<T extends Object>(
  BuildContext context, {
  required String title,
  required List<ProfileManagementSheetOption<T>> options,
}) async {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
    return null;
  }
  final navigator = Navigator.of(context);
  if (_activeManagementSheets[navigator] == true) return null;
  _activeManagementSheets[navigator] = true;
  var finished = false;
  final entries = List<ProfileManagementSheetOption<T>>.unmodifiable(options);
  try {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => ProfileManagementSheet<T>(
        title: title,
        options: entries,
        onSelected: (value) {
          if (finished ||
              !sheetContext.mounted ||
              ModalRoute.of(sheetContext)?.isCurrent != true) {
            return;
          }
          finished = true;
          Navigator.of(sheetContext).pop(value);
        },
      ),
    );
  } finally {
    _activeManagementSheets[navigator] = false;
  }
}

/// One visual language for profile-management menus, independent of routing.
class ProfileManagementSheet<T extends Object> extends StatelessWidget {
  const ProfileManagementSheet({
    super.key,
    required this.title,
    required this.options,
    required this.onSelected,
  });
  final String title;
  final List<ProfileManagementSheetOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < options.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              CustomPaint(
                foregroundPainter: const _ManagementOutlinePainter(),
                child: Material(
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.surfaceContainerHighest,
                          scheme.surfaceContainer,
                        ],
                      ),
                    ),
                    child: InkWell(
                      key: options[index].key,
                      onTap: () => onSelected(options[index].value),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                options[index].icon,
                                color: scheme.onSurface,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  options[index].label,
                                  style: TextStyle(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: scheme.onSurfaceVariant,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManagementOutlinePainter extends CustomPainter {
  const _ManagementOutlinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.brandGradient,
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(.5), const Radius.circular(18)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ManagementOutlinePainter oldDelegate) => false;
}
