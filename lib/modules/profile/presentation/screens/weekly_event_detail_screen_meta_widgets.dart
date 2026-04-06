// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

part of 'weekly_event_detail_screen.dart';

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? imageUrl;
  final VoidCallback? onTap;

  const _MetaChip({
    required this.icon,
    required this.text,
    this.imageUrl,
    this.onTap,
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inputFill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isInteractive
                  ? AppColors.white.withValues(alpha: 0.14)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MetaLeadingVisual(
                icon: icon,
                imageUrl: hasImage ? resolvedImage : null,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: isInteractive
                    ? ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: AppColors.brandGradient,
                          ).createShader(bounds);
                        },
                        child: Text(
                          text,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Text(
                        text,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              if (isInteractive) ...[
                const SizedBox(width: 6),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ).createShader(bounds);
                  },
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
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

  const _MetaLeadingVisual({required this.icon, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _gradientMetaIcon(icon: icon),
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

  const _GradientIcon({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ).createShader(bounds);
      },
      child: Icon(icon, size: size, color: Colors.white),
    );
  }
}
