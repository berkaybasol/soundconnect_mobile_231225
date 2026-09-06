import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/event_poster_fallback.dart';
import '../../domain/entities/venue_event_detail.dart';
import '../../domain/band_repository.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/venue_event_repository.dart';
import 'weekly_event_detail_screen.dart';

part 'weekly_event_carousel_card.dart';
part 'weekly_event_carousel_card_methods.dart';

bool _isNetworkImage(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return false;
  final uri = Uri.tryParse(raw);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

bool _isAssetImage(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return false;
  return raw.startsWith('assets/');
}

class WeeklyEventCarousel extends StatelessWidget {
  final List<WeeklyCalendarEvent> items;
  final EdgeInsetsGeometry padding;
  final bool compactTitle;

  WeeklyEventCarousel({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.compactTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 88,
          child: Center(
            child: Text(
              'Bu hafta için etkinlik bulunamadı.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    // Reserve space for two title lines and the two metadata rows when the
    // system uses larger text, while preserving the normal profile layout.
    final extraTextHeight =
        (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(
          0.0,
          double.infinity,
        ) *
        6;
    return SizedBox(
      height: (compactTitle ? 244 : 260) + extraTextHeight,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          final event = items[index];
          return _WeeklyEventCard(
            key: ValueKey<String>('weekly-event-${event.id}'),
            event: event,
            compactTitle: compactTitle,
          );
        },
      ),
    );
  }
}
