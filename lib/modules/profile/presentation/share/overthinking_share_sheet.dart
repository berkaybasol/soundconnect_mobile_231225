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
  backgroundColor: AppColors.navBlueDeep,
  barrierColor: Colors.black.withValues(alpha: 0.65),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    side: BorderSide(color: Color(0xFF2A3244)),
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
  Widget build(BuildContext context) => StoryShareSheet(
    bytes: prepared.bytes,
    accessibilityDescription: prepared.data.accessibilityDescription,
    title: 'Overthinking’i paylaş',
    keyPrefix: 'overthinking-share',
    validityChanges: validityChanges,
    isValid: isValid,
  );
}
