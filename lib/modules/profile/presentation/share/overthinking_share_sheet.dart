import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import 'overthinking_share_service.dart';
import 'story_share_sheet.dart';

Future<EventShareTarget?> showOverthinkingShareSheet(
  BuildContext context,
  PreparedOverthinkingShare prepared, {
  Listenable? validityChanges,
  bool Function()? isValid,
}) => showModalBottomSheet<EventShareTarget>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  barrierColor: Colors.black.withValues(alpha: 0.65),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    side: BorderSide(
      color: Theme.of(context).brightness == Brightness.dark
          ? Theme.of(context).colorScheme.outline
          : AppColors.legacyBorder(const Color(0xFF2A3244)),
    ),
  ),
  builder: (_) => OverthinkingShareSheet(
    prepared: prepared,
    validityChanges: validityChanges,
    isValid: isValid,
  ),
);

class OverthinkingShareSheet extends StatelessWidget {
  const OverthinkingShareSheet({
    super.key,
    required this.prepared,
    this.validityChanges,
    this.isValid,
  });

  final PreparedOverthinkingShare prepared;
  final Listenable? validityChanges;
  final bool Function()? isValid;

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return StoryShareSheet(
      bytes: prepared.bytes,
      accessibilityDescription: prepared.data.accessibilityDescription,
      title: 'Overthinking’i paylaş',
      keyPrefix: 'overthinking-share',
      useThemeColors: true,
      validityChanges: validityChanges,
      isValid: isValid,
    );
  }
}
