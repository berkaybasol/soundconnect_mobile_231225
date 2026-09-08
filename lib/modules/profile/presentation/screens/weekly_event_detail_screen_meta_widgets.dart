part of 'weekly_event_detail_screen.dart';

class _ProfileIdentityRow extends StatelessWidget {
  final _MetaChip performer;
  final _MetaChip venue;

  const _ProfileIdentityRow({required this.performer, required this.venue});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final performerSize = performer.preferredSize(context);
        final venueSize = venue.preferredSize(context);
        var performerWidth = performerSize.width;
        var venueWidth = venueSize.width;
        final available = constraints.hasBoundedWidth
            ? (constraints.maxWidth - gap).clamp(0.0, double.infinity)
            : performerWidth + venueWidth;

        // Short names keep their natural width. Only competing long names
        // share the remaining space, so neither identity pushes off this row.
        if (performerWidth + venueWidth > available) {
          final half = available / 2;
          if (performerWidth <= half) {
            venueWidth = available - performerWidth;
          } else if (venueWidth <= half) {
            performerWidth = available - venueWidth;
          } else {
            performerWidth = half;
            venueWidth = available - half;
          }
        }

        return SizedBox(
          width: constraints.hasBoundedWidth ? double.infinity : null,
          height: performerSize.height > venueSize.height
              ? performerSize.height
              : venueSize.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: performerWidth, child: performer),
              const SizedBox(width: gap),
              SizedBox(width: venueWidth, child: venue),
            ],
          ),
        );
      },
    );
  }
}

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

  static const _horizontalPadding = 10.0;
  static const _verticalPadding = 8.0;
  static const _borderWidth = 1.0;
  static const _leadingSize = 20.0;
  static const _contentGap = 6.0;
  static const _chevronSize = 14.0;
  static const _infoTargetSize = 48.0;

  TextStyle _labelStyle(BuildContext context) {
    final theme = Theme.of(context);
    return (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
      color: onTap != null ? AppColors.white : theme.colorScheme.onSurface,
      fontSize: 12,
      fontWeight: MediaQuery.boldTextOf(context)
          ? FontWeight.bold
          : onTap != null
          ? FontWeight.w600
          : FontWeight.w500,
    );
  }

  Size preferredSize(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _labelStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
      ellipsis: '…',
    )..layout();
    final labelSize = painter.size;
    painter.dispose();
    final suffixWidth =
        (onInfoTap != null ? _infoTargetSize : 0) +
        (onTap != null ? _contentGap + _chevronSize : 0);
    return Size(
      // Round up to avoid subpixel clipping of an otherwise fitting name.
      labelSize.width.ceilToDouble() +
          _horizontalPadding * 2 +
          _borderWidth * 2 +
          _leadingSize +
          _contentGap +
          suffixWidth,
      (labelSize.height + _verticalPadding * 2 + _borderWidth * 2).clamp(
        onInfoTap != null ? _infoTargetSize + _borderWidth * 2 : 48.0,
        double.infinity,
      ),
    );
  }

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
            horizontal: _horizontalPadding,
            vertical: onInfoTap == null ? _verticalPadding : 0,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              width: _borderWidth,
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
              SizedBox(
                width: singleLine ? _leadingSize : null,
                height: singleLine ? _leadingSize : null,
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: _MetaLeadingVisual(
                    icon: icon,
                    imageUrl: hasImage ? resolvedImage : null,
                  ),
                ),
              ),
              const SizedBox(width: _contentGap),
              Flexible(
                child: Tooltip(
                  message: singleLine ? text : '',
                  excludeFromSemantics: true,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: singleLine ? double.infinity : 220,
                    ),
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
                              style: _labelStyle(context),
                            ),
                          )
                        : Text(
                            text,
                            maxLines: singleLine ? 1 : null,
                            overflow: TextOverflow.ellipsis,
                            style: _labelStyle(context),
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
                    minWidth: _infoTargetSize,
                    minHeight: _infoTargetSize,
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
                const SizedBox(width: _contentGap),
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
                    size: _chevronSize,
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
