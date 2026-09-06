import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/gradient_text.dart';

class VenueCalendarProfileHeader extends StatelessWidget {
  final String? imageUrl;
  final String venueName;
  final String locationLabel;

  const VenueCalendarProfileHeader({
    super.key,
    required this.imageUrl,
    required this.venueName,
    required this.locationLabel,
  });

  bool get _hasImage {
    final raw = imageUrl?.trim();
    if (raw == null || raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 76,
          height: 76,
          padding: const EdgeInsets.all(1.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: AppColors.brandGradient),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandGradient[3].withValues(alpha: 0.22),
                blurRadius: 18,
              ),
            ],
          ),
          child: ClipOval(
            child: ColoredBox(
              color: AppColors.navBlueDeep,
              child: _hasImage
                  ? AppCachedNetworkImage(
                      imageUrl: imageUrl!.trim(),
                      width: 74,
                      height: 74,
                      fit: BoxFit.cover,
                      cacheWidth: 228,
                      cacheHeight: 228,
                      errorBuilder: (_) => const _VenueAvatarFallback(),
                    )
                  : const _VenueAvatarFallback(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isLight
                  ? Text(
                      venueName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 21,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    )
                  : GradientText(
                      text: venueName,
                      gradient: LinearGradient(colors: AppColors.brandGradient),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1.08,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.35,
                      ),
                    ),
              if (locationLabel.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: scheme.onSurfaceVariant,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VenueAvatarFallback extends StatelessWidget {
  const _VenueAvatarFallback();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(11),
      child: Image.asset(
        'assets/logotransparent.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.storefront_outlined,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 30,
        ),
      ),
    );
  }
}

class VenueCalendarCreateButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool saving;

  const VenueCalendarCreateButton({
    super.key,
    required this.onTap,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null && !saving;
    return AnimatedOpacity(
      opacity: enabled ? 1 : 0.58,
      duration: const Duration(milliseconds: 160),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(0.8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppColors.brandGradient),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Material(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8.2),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (saving)
                  SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onSurface,
                    ),
                  )
                else
                  ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => LinearGradient(
                      colors: AppColors.brandGradient,
                    ).createShader(bounds),
                    child: Icon(
                      Icons.add_rounded,
                      color: scheme.onSurface,
                      size: 20,
                    ),
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    saving ? 'Ekleniyor...' : 'Etkinlik Ekle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
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

class VenueCalendarHistoryHeader extends StatelessWidget {
  final int count;
  final String title;

  const VenueCalendarHistoryHeader({
    super.key,
    required this.count,
    this.title = 'Geçmiş Etkinlikler',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$count',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class VenueCalendarEmptyState extends StatelessWidget {
  final bool history;
  final String? message;

  const VenueCalendarEmptyState({
    super.key,
    required this.history,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            history ? Icons.history_rounded : Icons.event_outlined,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
            size: 22,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message ??
                  (history ? 'Geçmiş etkinlik yok.' : 'Takvimde etkinlik yok.'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VenueCalendarErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const VenueCalendarErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.error.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: scheme.error, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurface, fontSize: 11.5),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Yenile')),
        ],
      ),
    );
  }
}
