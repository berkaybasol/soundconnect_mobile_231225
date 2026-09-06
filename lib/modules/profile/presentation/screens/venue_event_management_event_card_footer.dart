part of 'venue_event_management_event_card.dart';

class _VenueCalendarEventInfo extends StatelessWidget {
  final String title;
  final String performerName;
  final String dateLabel;
  final String timeLabel;
  final bool history;

  const _VenueCalendarEventInfo({
    required this.title,
    required this.performerName,
    required this.dateLabel,
    required this.timeLabel,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryColor = history
        ? scheme.onSurface.withValues(alpha: 0.82)
        : scheme.onSurface;
    final secondaryColor = scheme.onSurfaceVariant.withValues(
      alpha: history ? 0.78 : 1,
    );
    final artist = performerName.trim().isEmpty ? 'Sanatçı' : performerName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: primaryColor,
            fontSize: 15,
            height: 1.18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.15,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: secondaryColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 10,
          runSpacing: 5,
          children: [
            _VenueCalendarMeta(
              icon: Icons.calendar_today_outlined,
              text: dateLabel,
              history: history,
            ),
            _VenueCalendarMeta(
              icon: Icons.schedule_outlined,
              text: timeLabel,
              history: history,
            ),
          ],
        ),
      ],
    );
  }
}

class _VenueCalendarMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool history;

  const _VenueCalendarMeta({
    required this.icon,
    required this.text,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = history
        ? scheme.onSurfaceVariant.withValues(alpha: 0.72)
        : AppColors.coralLight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
