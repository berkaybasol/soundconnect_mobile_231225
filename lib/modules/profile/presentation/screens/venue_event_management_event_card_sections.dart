part of 'venue_event_management_event_card.dart';

class _VenueCalendarEventPosterStack extends StatelessWidget {
  final bool hasPoster;
  final String? posterUrl;
  final String dateLabel;
  final bool saving;
  final VoidCallback onDelete;

  _VenueCalendarEventPosterStack({
    required this.hasPoster,
    required this.posterUrl,
    required this.dateLabel,
    required this.saving,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Stack(
        children: [
          Positioned.fill(
            child: hasPoster
                ? AppCachedNetworkImage(
                    imageUrl: posterUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.surfaceContainer,
                          AppColors.navBlueDeep,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.image_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.navBlueDeep.withValues(alpha: 0.18),
                    Colors.transparent,
                    AppColors.navBlueDeep.withValues(alpha: 0.34),
                  ],
                  stops: [0, 0.42, 1],
                ),
              ),
            ),
          ),
          Positioned(
            left: -12,
            right: -12,
            top: -18,
            child: IgnorePointer(
              child: Container(
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.white.withValues(alpha: 0.16),
                      AppColors.coralLight.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(40),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.pureBlack.withValues(alpha: 0.30),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -24,
            top: 26,
            child: IgnorePointer(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.white.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -18,
            top: 54,
            child: IgnorePointer(
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.coralLight.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -30,
            right: -30,
            bottom: -22,
            child: IgnorePointer(
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, 1),
                    radius: 1.15,
                    colors: [
                      AppColors.coralAlt.withValues(alpha: 0.36),
                      AppColors.coralLight.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 82,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.pureBlack.withValues(alpha: 0.50),
                    AppColors.navBlueDeep.withValues(alpha: 0.24),
                    Colors.transparent,
                  ],
                  stops: [0, 0.42, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.navBlueDeep.withValues(alpha: 0.86),
                    AppColors.navBlueDeep.withValues(alpha: 0.54),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.navBlueDeep.withValues(alpha: 0.62),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(14)),
                border: Border.all(
                  color: AppColors.white.withValues(alpha: 0.08),
                ),
              ),
              child: IconButton(
                tooltip: 'Sil',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: saving ? null : onDelete,
                icon: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) {
                    return LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ).createShader(bounds);
                  },
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.white,
                    size: 21,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
