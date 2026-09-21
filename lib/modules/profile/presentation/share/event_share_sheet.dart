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
  Widget build(BuildContext context) {
    Theme.of(context);
    return StoryShareSheet(
      bytes: prepared.bytes,
      accessibilityDescription: prepared.data.accessibilityDescription,
      title: 'Etkinliği paylaş',
      keyPrefix: 'event-share',
      useThemeColors: true,
      validityChanges: validityChanges,
      isValid: isValid,
    );
  }
}
