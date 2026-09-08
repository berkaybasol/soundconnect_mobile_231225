import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';

/// The compact identity card shared by profile members, venues and artists.
class ProfileMiniCard extends StatelessWidget {
  const ProfileMiniCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.fallbackIcon,
    this.subtitle,
    this.titleBadge,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? imageUrl;
  final IconData fallbackIcon;
  final Widget? titleBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final caption = subtitle?.trim();
    Widget fallback(BuildContext _) =>
        Icon(fallbackIcon, color: colors.onSurfaceVariant, size: 20);

    return SizedBox(
      width: 168,
      child: Material(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.65),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.surfaceContainer,
                  child: ClipOval(
                    child: AppCachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 32,
                      height: 32,
                      cacheWidth: 96,
                      cacheHeight: 96,
                      placeholderBuilder: fallback,
                      errorBuilder: fallback,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Tooltip(
                              message: title,
                              excludeFromSemantics: true,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (titleBadge != null) ...[
                            const SizedBox(width: 4),
                            titleBadge!,
                          ],
                        ],
                      ),
                      if (caption != null && caption.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Tooltip(
                          message: caption,
                          excludeFromSemantics: true,
                          child: Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps rows compact while allowing large accessibility text to grow vertically.
class ProfileMiniCarousel extends StatelessWidget {
  const ProfileMiniCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.hasSubtitle = false,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool hasSubtitle;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final textHeight =
        scaler.scale(13) * 1.35 +
        (hasSubtitle ? scaler.scale(11) * 1.35 + 3 : 0);
    return SizedBox(
      height: (textHeight + 16).clamp(52.0, double.infinity).ceilToDouble(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
