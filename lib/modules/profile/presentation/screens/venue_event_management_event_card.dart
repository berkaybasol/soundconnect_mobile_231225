import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/event_poster_fallback.dart';

part 'venue_event_management_event_card_sections.dart';
part 'venue_event_management_event_card_footer.dart';

class VenueCalendarEventCard extends StatelessWidget {
  final String? posterImage;
  final String title;
  final String dateLabel;
  final String timeLabel;
  final String performerName;
  final VoidCallback onTap;
  final bool saving;
  final VoidCallback? onDelete;

  const VenueCalendarEventCard({
    super.key,
    required this.posterImage,
    required this.title,
    required this.dateLabel,
    required this.timeLabel,
    required this.performerName,
    required this.onTap,
    required this.saving,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _VenueCalendarCompactCard(
      posterImage: posterImage,
      title: title,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      performerName: performerName,
      onTap: onTap,
      saving: saving,
      onDelete: onDelete,
      history: false,
    );
  }
}

class VenueCalendarPastEventCard extends StatelessWidget {
  final String? posterImage;
  final String title;
  final String dateLabel;
  final String timeLabel;
  final String performerName;
  final VoidCallback onTap;
  final bool saving;
  final VoidCallback? onDelete;

  const VenueCalendarPastEventCard({
    super.key,
    required this.posterImage,
    required this.title,
    required this.dateLabel,
    required this.timeLabel,
    required this.performerName,
    required this.onTap,
    required this.saving,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _VenueCalendarCompactCard(
      posterImage: posterImage,
      title: title,
      dateLabel: dateLabel,
      timeLabel: timeLabel,
      performerName: performerName,
      onTap: onTap,
      saving: saving,
      onDelete: onDelete,
      history: true,
    );
  }
}

class _VenueCalendarCompactCard extends StatelessWidget {
  final String? posterImage;
  final String title;
  final String dateLabel;
  final String timeLabel;
  final String performerName;
  final VoidCallback onTap;
  final bool saving;
  final VoidCallback? onDelete;
  final bool history;

  const _VenueCalendarCompactCard({
    required this.posterImage,
    required this.title,
    required this.dateLabel,
    required this.timeLabel,
    required this.performerName,
    required this.onTap,
    required this.saving,
    required this.onDelete,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final showPoster = textScale < 1.6;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: history ? 0.58 : 0.9,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showPoster) ...[
                _VenueCalendarEventArtwork(
                  posterImage: posterImage,
                  title: title,
                  history: history,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _VenueCalendarEventInfo(
                  title: title,
                  performerName: performerName,
                  dateLabel: dateLabel,
                  timeLabel: timeLabel,
                  history: history,
                ),
              ),
              const SizedBox(width: 4),
              if (onDelete != null)
                _VenueCalendarEventMenuButton(
                  saving: saving,
                  onDelete: onDelete!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
