import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/collab_discovery_models.dart';

class CollabGradientFrame extends StatelessWidget {
  const CollabGradientFrame({
    required this.child,
    this.highlighted = false,
    this.radius = 18,
    this.strokeWidth = 1.2,
    this.padding,
    super.key,
  });

  final Widget child;
  final bool highlighted;
  final double radius;
  final double strokeWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: highlighted
            ? LinearGradient(colors: AppColors.brandGradient)
            : null,
        color: highlighted ? null : theme.dividerColor,
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: AppColors.brandGradient.last.withValues(alpha: 0.12),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(strokeWidth),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - strokeWidth),
          child: ColoredBox(
            color: theme.colorScheme.surfaceContainer,
            child: padding == null
                ? child
                : Padding(padding: padding!, child: child),
          ),
        ),
      ),
    );
  }
}

class CollabChoiceChip extends StatelessWidget {
  const CollabChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: CollabGradientFrame(
          highlighted: selected,
          radius: 999,
          strokeWidth: selected ? 1.35 : 1,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CollabListingCard extends StatelessWidget {
  const CollabListingCard({
    required this.listing,
    required this.saved,
    required this.onTap,
    required this.onSave,
    this.interactive = true,
    this.showSave = true,
    this.showCadence = true,
    super.key,
  });

  final CollabDiscoveryListing listing;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final bool interactive;
  final bool showSave;
  final bool showCadence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: interactive,
      label: listing.title,
      child: InkWell(
        onTap: interactive ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: CollabGradientFrame(
          highlighted: listing.isHighlighted,
          radius: 20,
          strokeWidth: listing.isHighlighted ? 1.5 : 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CollabProfileAvatar(listing: listing),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  listing.ownerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                              if (listing.isHighlighted) ...[
                                const SizedBox(width: 7),
                                const CollabFeaturedPill(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            listing.ownerSubtitle,
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
                    if (showSave)
                      IconButton(
                        onPressed: interactive ? onSave : null,
                        tooltip: saved
                            ? 'Kaydedilenlerden çıkar'
                            : 'İlanı kaydet',
                        icon: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: saved
                              ? AppColors.coralLight
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                    height: 1.22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (showCadence) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      CollabStatusPill(
                        label: listing.cadence.label,
                        color: AppColors.socialPink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                ] else
                  const SizedBox(height: 13),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: [
                        _MetaItem(
                          width: itemWidth,
                          icon: Icons.location_on_outlined,
                          label: listing.location,
                        ),
                        if (listing.cadence == CollabCadence.extra)
                          _MetaItem(
                            width: itemWidth,
                            icon: Icons.calendar_month_outlined,
                            label: _scheduleText(listing),
                          ),
                        if (listing.cadence == CollabCadence.extra ||
                            (listing.profileKind == CollabProfileKind.venue &&
                                listing.feeAmount != null))
                          _MetaItem(
                            width: itemWidth,
                            icon: Icons.payments_outlined,
                            label: _feeText(listing.feeAmount),
                          ),
                        _MetaItem(
                          width: itemWidth,
                          icon: _wantedIcon(listing.wantedKind),
                          label: _wantedText(listing),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _scheduleText(CollabDiscoveryListing listing) {
    final time = listing.timeLabel?.trim();
    return time == null || time.isEmpty
        ? listing.scheduleLabel
        : '${listing.scheduleLabel} · $time';
  }

  String _feeText(int? amount) {
    if (amount == null) return 'Ücret belirtilmemiş';
    final value = amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return '₺$value';
  }

  String _wantedText(CollabDiscoveryListing listing) {
    return listing.wantedSummary;
  }

  IconData _wantedIcon(CollabProfileKind kind) => switch (kind) {
    CollabProfileKind.musician => Icons.music_note_outlined,
    CollabProfileKind.band => Icons.groups_2_outlined,
    CollabProfileKind.venue => Icons.storefront_outlined,
    CollabProfileKind.studio => Icons.graphic_eq_rounded,
  };
}

class CollabProfileAvatar extends StatelessWidget {
  const CollabProfileAvatar({required this.listing, this.size = 52, super.key});

  final CollabDiscoveryListing listing;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CollabIdentityAvatar(
      initials: listing.ownerInitials,
      profileKind: listing.profileKind,
      avatarAsset: listing.avatarAsset,
      size: size,
    );
  }
}

class CollabIdentityAvatar extends StatelessWidget {
  const CollabIdentityAvatar({
    required this.initials,
    required this.profileKind,
    this.avatarAsset,
    this.size = 52,
    super.key,
  });

  final String initials;
  final CollabProfileKind profileKind;
  final String? avatarAsset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = switch (profileKind) {
      CollabProfileKind.musician => [
        AppColors.musicianBlue,
        AppColors.brandGradient.last,
      ],
      CollabProfileKind.band => [AppColors.socialOrange, AppColors.socialPink],
      CollabProfileKind.venue => [AppColors.coral, AppColors.socialPurple],
      CollabProfileKind.studio => [
        AppColors.socialPurple,
        AppColors.musicianBlue,
      ],
    };
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: ClipOval(
        child: avatarAsset == null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              )
            : ColoredBox(
                color: AppColors.pureBlack,
                child: Image.asset(avatarAsset!, fit: BoxFit.contain),
              ),
      ),
    );
  }
}

class CollabFeaturedPill extends StatelessWidget {
  const CollabFeaturedPill({super.key});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFA000);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: amber.withValues(alpha: 0.72)),
      ),
      child: const Text(
        'Öne Çıkan',
        style: TextStyle(
          color: Color(0xFFFFD180),
          fontWeight: FontWeight.w800,
          fontSize: 9.5,
        ),
      ),
    );
  }
}

class CollabStatusPill extends StatelessWidget {
  const CollabStatusPill({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.76)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.width,
    required this.icon,
    required this.label,
  });

  final double width;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
