import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/collab_types.dart';
import '../../domain/entities/collab_actor.dart';
import '../../domain/entities/collab_listing.dart';
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
    return _StatusPill(label: status.label, color: color, icon: icon);
  }
}

class CollabListingStatusPill extends StatelessWidget {
  const CollabListingStatusPill({required this.status, super.key});

  final CollabListingStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      CollabListingStatus.draft => (
        'Taslak',
        AppColors.socialPurple,
        Icons.edit_note_rounded,
      ),
      CollabListingStatus.open => (
        'Yayında',
        AppColors.spotifyGreen,
        Icons.public_rounded,
      ),
      CollabListingStatus.closed => (
        'Kapalı',
        Theme.of(context).colorScheme.onSurfaceVariant,
        Icons.lock_outline_rounded,
      ),
      CollabListingStatus.expired => (
        'Süresi doldu',
        AppColors.coral,
        Icons.event_busy_rounded,
      ),
    };
    return _StatusPill(label: label, color: color, icon: icon);
  }
}

class CollabJobStatusPill extends StatelessWidget {
  const CollabJobStatusPill({required this.status, super.key});

  final CollabJobStatus status;

  @override
  Widget build(BuildContext context) {
    return _StatusPill(
      label: status == CollabJobStatus.active ? 'Aktif iş' : 'Tamamlandı',
      color: status == CollabJobStatus.active
          ? AppColors.socialOrange
          : AppColors.spotifyGreen,
      icon: status == CollabJobStatus.active
          ? Icons.handshake_outlined
          : Icons.verified_rounded,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
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
              label,
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

class CollabActorAvatar extends StatelessWidget {
  const CollabActorAvatar({required this.actor, this.size = 50, super.key});

  final CollabActor actor;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context) => ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Text(
          actor.initials,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: size * .28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    return ClipOval(
      child: AppCachedNetworkImage(
        imageUrl: actor.avatarUrl,
        width: size,
        height: size,
        cacheWidth: (size * 2).round(),
        cacheHeight: (size * 2).round(),
        placeholderBuilder: fallback,
        errorBuilder: fallback,
      ),
    );
  }
}

class CollabActorHeader extends StatelessWidget {
  const CollabActorHeader({
    required this.actor,
    this.trailing,
    this.onTap,
    super.key,
  });

  final CollabActor actor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          CollabActorAvatar(actor: actor),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actor.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${actor.profileType.label} · ${actor.rating.toStringAsFixed(1)} ★ · ${actor.completedJobCount} iş',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class CollabCardAction extends StatelessWidget {
  const CollabCardAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tone = CollabCardActionTone.neutral,
    this.busy = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final CollabCardActionTone tone;
  final bool busy;

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
        child: busy
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fill ? AppColors.white : color,
                ),
              )
            : Row(
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
          onTap: busy ? null : onPressed,
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

class CollabPagedFooter extends StatelessWidget {
  const CollabPagedFooter({
    required this.loading,
    required this.hasError,
    required this.onRetry,
    super.key,
  });

  final bool loading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (!loading && !hasError) return const SizedBox(height: 28);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(strokeWidth: 2)
            : TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Devamını yeniden yükle'),
              ),
      ),
    );
  }
}

String collabListingStatusLabel(CollabListingStatus status) => switch (status) {
  CollabListingStatus.draft => 'Taslak',
  CollabListingStatus.open => 'Yayında',
  CollabListingStatus.closed => 'Kapalı',
  CollabListingStatus.expired => 'Süresi doldu',
};

String collabJobStatusLabel(CollabJobStatus status) =>
    status == CollabJobStatus.active ? 'Aktif' : 'Tamamlandı';

String collabShortDate(DateTime? value) {
  if (value == null) return 'Tarih belirtilmedi';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} · ${two(local.hour)}:${two(local.minute)}';
}

String collabListingSchedule(CollabListing listing) {
  if (listing.cadence == CollabCadence.regular) return 'Düzenli';
  return collabShortDate(listing.scheduledAt);
}

String collabFeeText(CollabListing listing) {
  if (listing.feeStatus == CollabFeeStatus.notApplicable) {
    return 'Ücret uygulanmaz';
  }
  if (listing.feeStatus == CollabFeeStatus.unspecified ||
      listing.feeAmountMinor == null) {
    return 'Ücret belirtilmedi';
  }
  final amount = listing.feeAmountMinor! / 100;
  final formatted = amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toStringAsFixed(2);
  return '$formatted ${listing.currency ?? 'TRY'}';
}
