part of 'weekly_event_detail_screen.dart';

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onInfoTap;
  final bool singleLine;
  final bool centerContent;

  const _MetaChip({
    super.key,
    required this.icon,
    required this.text,
    this.imageUrl,
    this.onTap,
    this.onInfoTap,
    this.singleLine = false,
    this.centerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImage = imageUrl?.trim();
    final hasImage = _isNetworkLikePath(resolvedImage);
    final isInteractive = onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: 10,
            vertical: onInfoTap == null ? 8 : 0,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isInteractive
                  ? AppColors.white.withValues(alpha: 0.14)
                  : Theme.of(context).dividerColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: centerContent
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              _MetaLeadingVisual(
                icon: icon,
                imageUrl: hasImage ? resolvedImage : null,
              ),
              SizedBox(width: 6),
              Flexible(
                child: Tooltip(
                  message: singleLine ? text : '',
                  excludeFromSemantics: true,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 220),
                    child: isInteractive
                        ? ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: AppColors.brandGradient,
                              ).createShader(bounds);
                            },
                            child: Text(
                              text,
                              maxLines: singleLine ? 1 : null,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : Text(
                            text,
                            maxLines: singleLine ? 1 : null,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ),
              if (onInfoTap != null)
                IconButton(
                  key: const Key('event-performer-verification-info'),
                  tooltip: 'Katılım bilgisi',
                  onPressed: onInfoTap,
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  visualDensity: VisualDensity.standard,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.info_outline_rounded,
                    size: 17,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              if (isInteractive) ...[
                SizedBox(width: 6),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ).createShader(bounds);
                  },
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.white,
                    size: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLeadingVisual extends StatelessWidget {
  final IconData icon;
  final String? imageUrl;

  _MetaLeadingVisual({required this.icon, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: AppCachedNetworkImage(
          imageUrl: imageUrl,
          width: 20,
          height: 20,
          fit: BoxFit.cover,
          cacheWidth: 60,
          cacheHeight: 60,
          errorBuilder: (context) => _gradientMetaIcon(icon: icon),
        ),
      );
    }
    return _gradientMetaIcon(icon: icon);
  }

  Widget _gradientMetaIcon({required IconData icon}) {
    return _GradientIcon(icon: icon, size: 16);
  }
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  _GradientIcon({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ).createShader(bounds);
      },
      child: Icon(icon, size: size, color: AppColors.white),
    );
  }
}
