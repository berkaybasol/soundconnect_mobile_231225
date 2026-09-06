part of 'venue_event_management_event_card.dart';

class _VenueCalendarEventArtwork extends StatelessWidget {
  final String? posterImage;
  final String title;
  final bool history;

  const _VenueCalendarEventArtwork({
    required this.posterImage,
    required this.title,
    required this.history,
  });

  bool get _hasPoster {
    final raw = posterImage?.trim();
    if (raw == null || raw.isEmpty) return false;
    final uri = Uri.tryParse(raw);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 70,
      height: 82,
      padding: const EdgeInsets.all(0.8),
      decoration: BoxDecoration(
        gradient: history
            ? LinearGradient(
                colors: [scheme.outlineVariant, scheme.outlineVariant],
              )
            : LinearGradient(colors: AppColors.brandGradient),
        borderRadius: BorderRadius.circular(9),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_hasPoster)
              AppCachedNetworkImage(
                imageUrl: posterImage!.trim(),
                width: 68,
                height: 80,
                fit: BoxFit.cover,
                cacheWidth: 210,
                cacheHeight: 246,
                placeholderBuilder: (_) => EventPosterFallback(title: title),
                errorBuilder: (_) => EventPosterFallback(title: title),
              )
            else
              EventPosterFallback(title: title),
            if (history)
              ColoredBox(color: AppColors.navBlueDeep.withValues(alpha: 0.24)),
          ],
        ),
      ),
    );
  }
}

enum _VenueCalendarMenuAction { delete }

class _VenueCalendarEventMenuButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onDelete;

  const _VenueCalendarEventMenuButton({
    required this.saving,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<_VenueCalendarMenuAction>(
      enabled: !saving,
      tooltip: 'Etkinlik seçenekleri',
      onSelected: (action) {
        if (action == _VenueCalendarMenuAction.delete) onDelete();
      },
      color: scheme.surfaceContainerHighest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: .12)),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _VenueCalendarMenuAction.delete,
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: AppColors.coral,
                size: 19,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Etkinliği sil',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      child: SizedBox.square(
        dimension: 44,
        child: Icon(
          Icons.more_horiz_rounded,
          color: scheme.onSurfaceVariant,
          size: 20,
        ),
      ),
    );
  }
}
