import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/collab_application_models.dart';
import '../../domain/collab_discovery_models.dart';
import '../../domain/collab_management_models.dart';
import 'collab_discovery_widgets.dart';

enum CollabCardActionTone { neutral, brand, danger, success }

class CollabApplicationStatusPill extends StatelessWidget {
  const CollabApplicationStatusPill({required this.status, super.key});

  final CollabApplicationStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      CollabApplicationStatus.pending => (
        const Color(0xFFFFA000),
        Icons.hourglass_bottom_rounded,
      ),
      CollabApplicationStatus.accepted => (
        AppColors.spotifyGreen,
        Icons.check_circle_outline_rounded,
      ),
      CollabApplicationStatus.rejected => (
        AppColors.coral,
        Icons.cancel_outlined,
      ),
      CollabApplicationStatus.withdrawnByApplicant => (
        AppColors.socialPurple,
        Icons.undo_rounded,
      ),
      CollabApplicationStatus.invalidatedByListingClosure => (
        Theme.of(context).colorScheme.onSurfaceVariant,
        Icons.block_outlined,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.76)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              status.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CollabOwnedStatusPill extends StatelessWidget {
  const CollabOwnedStatusPill({required this.status, super.key});

  final CollabOwnedListingStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      CollabOwnedListingStatus.open => AppColors.spotifyGreen,
      CollabOwnedListingStatus.full => const Color(0xFFFFA000),
      CollabOwnedListingStatus.closed => Theme.of(
        context,
      ).colorScheme.onSurfaceVariant,
    };
    return CollabStatusPill(label: status.label, color: color);
  }
}

class CollabCardAction extends StatelessWidget {
  const CollabCardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = CollabCardActionTone.neutral,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final CollabCardActionTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      CollabCardActionTone.neutral => theme.colorScheme.onSurface,
      CollabCardActionTone.brand => AppColors.socialPurple,
      CollabCardActionTone.danger => AppColors.coral,
      CollabCardActionTone.success => AppColors.spotifyGreen,
    };
    final fill = tone == CollabCardActionTone.success && onPressed != null;
    final child = SizedBox(
      height: 42,
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: fill ? AppColors.white : color),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fill ? AppColors.white : color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Opacity(
      opacity: onPressed == null ? 0.52 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: fill
              ? Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.brandGradient),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: child,
                )
              : CollabGradientFrame(
                  highlighted: tone != CollabCardActionTone.neutral,
                  radius: 13,
                  strokeWidth: 1,
                  child: child,
                ),
        ),
      ),
    );
  }
}

class CollabActionsWrap extends StatelessWidget {
  const CollabActionsWrap({required this.actions, super.key});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions
              .map((action) => SizedBox(width: width, child: action))
              .toList(growable: false),
        );
      },
    );
  }
}

class CollabTinyMeta extends StatelessWidget {
  const CollabTinyMeta({
    required this.icon,
    required this.label,
    this.width,
    super.key,
  });

  final IconData icon;
  final String label;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: width,
      child: Row(
        mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

String collabScheduleText(CollabDiscoveryListing listing) {
  final time = listing.timeLabel?.trim();
  return time == null || time.isEmpty
      ? listing.scheduleLabel
      : '${listing.scheduleLabel} · $time';
}
