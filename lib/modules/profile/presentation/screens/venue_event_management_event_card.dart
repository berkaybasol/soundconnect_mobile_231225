import 'package:flutter/material.dart';

import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';

part 'venue_event_management_event_card_sections.dart';
part 'venue_event_management_event_card_footer.dart';

class VenueCalendarEventCard extends StatelessWidget {
  final String? posterImage;
  final String title;
  final String dateLabel;
  final String performerName;
  final VoidCallback onTap;
  final bool saving;
  final VoidCallback onDelete;

  VenueCalendarEventCard({
    super.key,
    required this.posterImage,
    required this.title,
    required this.dateLabel,
    required this.performerName,
    required this.onTap,
    required this.saving,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final posterUrl = posterImage?.trim();
    final hasPoster =
        posterUrl != null &&
        posterUrl.isNotEmpty &&
        Uri.tryParse(posterUrl)?.hasAbsolutePath == true;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: [
              BoxShadow(
                color: AppColors.pureBlack.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VenueCalendarEventPosterStack(
                  hasPoster: hasPoster,
                  posterUrl: posterUrl,
                  dateLabel: dateLabel,
                  saving: saving,
                  onDelete: onDelete,
                ),
                _VenueCalendarEventFooter(
                  performerName: performerName,
                  title: title,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
