import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import 'event_share_service.dart';
import 'story_share_sheet.dart';

Future<EventShareTarget?> showEventShareSheet(
  BuildContext context,
  PreparedEventShare prepared, {
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
  builder: (_) => EventShareSheet(
    prepared: prepared,
    validityChanges: validityChanges,
    isValid: isValid,
  ),
);

class EventShareSheet extends StatelessWidget {
  const EventShareSheet({
    super.key,
    required this.prepared,
    this.validityChanges,
    this.isValid,
  });

  final PreparedEventShare prepared;
  final Listenable? validityChanges;
  final bool Function()? isValid;

  @override
  Widget build(BuildContext context) => StoryShareSheet(
    bytes: prepared.bytes,
    accessibilityDescription: prepared.data.accessibilityDescription,
    title: 'Etkinliği paylaş',
    keyPrefix: 'event-share',
    validityChanges: validityChanges,
    isValid: isValid,
  );
}
