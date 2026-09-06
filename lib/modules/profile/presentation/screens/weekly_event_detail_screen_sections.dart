part of 'weekly_event_detail_screen.dart';

class _HeroHeader extends StatelessWidget {
  final WeeklyCalendarEvent event;
  final VoidCallback onImageTap;

  _HeroHeader({required this.event, required this.onImageTap});

  @override
  Widget build(BuildContext context) {
    final imagePath = event.imageAssetPath?.trim();
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            button: true,
            label: 'Afişi görüntüle',
            child: InkWell(
              excludeFromSemantics: true,
              onTap: onImageTap,
              child: _isNetworkLikePath(imagePath)
                  ? AppCachedNetworkImage(
                      imageUrl: imagePath,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      cacheProfile: AppImageCacheProfile.original,
                      placeholderBuilder: (context) => _imageFallback(event),
                      errorBuilder: (context) => _imageFallback(event),
                    )
                  : imagePath?.startsWith('assets/') == true
                  ? Image.asset(
                      imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imageFallback(event),
                    )
                  : _imageFallback(event),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0xCC0B1321)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 14,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.pureBlack.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      [
                        event.eventDate,
                        _eventTimeRange(event),
                      ].where((value) => value.trim().isNotEmpty).join(' - '),
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    event.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Material(
              color: AppColors.pureBlack.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
              child: IconButton(
                tooltip: 'Geri',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _eventClockLabel(String value) {
  final trimmed = value.trim();
  if (trimmed == '-') return '';
  final match = RegExp(
    r'^(\d{2}:\d{2})(?::\d{2}(?:\.\d+)?)?$',
  ).firstMatch(trimmed);
  return match?.group(1) ?? trimmed;
}

String _eventTimeRange(WeeklyCalendarEvent event) => [
  event.startTime,
  event.endTime,
].map(_eventClockLabel).where((value) => value.isNotEmpty).join(' - ');

Widget _imageFallback(WeeklyCalendarEvent event, {bool showDetails = false}) {
  return EventPosterFallback(
    title: event.title,
    dateLabel: [
      event.eventDate,
      _eventClockLabel(event.startTime),
    ].where((value) => value.trim().isNotEmpty).join(' • '),
    showDetails: showDetails,
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;

  _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  _ActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Match the musician/venue profile's Management Panel button exactly.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: AppColors.brandGradient),
      ),
      child: Padding(
        padding: const EdgeInsets.all(.7),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: TextButton.icon(
              onPressed: isLoading ? null : onPressed,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.white,
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: isLoading
                  ? Builder(
                      builder: (iconContext) => SizedBox.square(
                        dimension: IconTheme.of(iconContext).size ?? 18,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      ),
                    )
                  : Icon(icon, color: AppColors.white),
              label: Text(
                label,
                style: const TextStyle(color: AppColors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
