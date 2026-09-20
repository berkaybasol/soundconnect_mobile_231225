import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';

/// Shared visual primitives for direct-message surfaces.
///
/// These widgets intentionally contain no navigation or message state so the
/// DM presentation can evolve without coupling its visuals to conversation
/// behaviour.
class DmAvatar extends StatelessWidget {
  const DmAvatar({
    required this.size,
    this.imageUrl,
    this.fallbackText,
    this.fallbackIcon = Icons.person_outline_rounded,
    super.key,
  });

  final double size;
  final String? imageUrl;
  final String? fallbackText;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    Theme.of(context); // Rebuild palette colors when the theme changes.
    final normalizedImageUrl = imageUrl?.trim();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.35),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.isLight ? AppColors.avatarBackground : null,
        gradient: AppColors.isLight
            ? null
            : LinearGradient(colors: AppColors.brandGradient),
      ),
      child: ClipOval(
        child: normalizedImageUrl?.isNotEmpty == true
            ? AppCachedNetworkImage(
                imageUrl: normalizedImageUrl,
                width: size,
                height: size,
                cacheWidth: (size * 3).round(),
                cacheHeight: (size * 3).round(),
                placeholderBuilder: (_) => _fallback(),
                errorBuilder: (_) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final normalizedFallbackText = fallbackText?.trim() ?? '';
    final initial = normalizedFallbackText.isEmpty
        ? null
        : String.fromCharCode(normalizedFallbackText.runes.first);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.isLight ? AppColors.avatarBackground : null,
        gradient: AppColors.isLight
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.musicianBlue.withValues(alpha: 0.88),
                  AppColors.socialPurple.withValues(alpha: 0.88),
                ],
              ),
      ),
      child: Center(
        child: initial == null
            ? Icon(
                fallbackIcon,
                size: size * 0.42,
                color: AppColors.isLight
                    ? AppColors.avatarForeground
                    : AppColors.white,
              )
            : Text(
                initial.toUpperCase(),
                style: TextStyle(
                  color: AppColors.isLight
                      ? AppColors.avatarForeground
                      : AppColors.white,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
      ),
    );
  }
}

class DmHeaderAction extends StatelessWidget {
  const DmHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.outline),
                ),
                child: Icon(icon, size: 20, color: colors.onSurface),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DmGradientIconPanel extends StatelessWidget {
  const DmGradientIconPanel({required this.icon, this.size = 68, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(colors: AppColors.decorativeGradient),
        boxShadow: [
          BoxShadow(
            color: AppColors.isLight
                ? AppColors.avatarShadow.withValues(alpha: 0.12)
                : AppColors.socialPurple.withValues(alpha: 0.16),
            blurRadius: 22,
            spreadRadius: -7,
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(size * 0.30),
        ),
        child: Center(
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(
              colors: AppColors.decorativeGradient,
            ).createShader(bounds),
            child: Icon(icon, size: size * 0.42, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}
