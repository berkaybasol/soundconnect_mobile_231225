import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../analytics/presentation/widgets/analytics_tracking.dart';
import '../../../../shared/images/app_cached_network_image.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/event_poster_fallback.dart';
import '../../domain/entities/venue_event_detail.dart';
import '../../domain/band_repository.dart';
import '../../domain/musician_profile_repository.dart';
import '../../domain/venue_event_repository.dart';
import '../../domain/weekly_calendar_date_policy.dart';
import 'weekly_calendar_day_monitor.dart';
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

class WeeklyEventCarousel extends StatefulWidget {
  final List<WeeklyCalendarEvent> items;
  final EdgeInsetsGeometry padding;
  final bool compactTitle;
  final bool trackImpressions;
  final DateTime Function()? now;

  WeeklyEventCarousel({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.compactTitle = false,
    this.trackImpressions = true,
    this.now,
  });

  @override
  State<WeeklyEventCarousel> createState() => _WeeklyEventCarouselState();
}

class _WeeklyEventCarouselState extends State<WeeklyEventCarousel>
    with WeeklyCalendarDayMonitor<WeeklyEventCarousel> {
  @override
  DateTime calendarNow() => widget.now?.call() ?? DateTime.now();

  bool _inCurrentWeek(WeeklyCalendarEvent event) =>
      WeeklyCalendarDatePolicy.contains(
        WeeklyCalendarDatePolicy.parseDisplayDate(event.eventDate),
        WeeklyCalendarDatePolicy.today(calendarNow()),
      );

  @override
  Widget build(BuildContext context) {
    final items = widget.items.where(_inCurrentWeek).toList(growable: false);
    final compactTitle = widget.compactTitle;
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
        padding: widget.padding,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          final event = items[index];
          return TrackEventImpression(
            key: ValueKey<String>('weekly-event-exposure-${event.id}'),
            eventId: event.id,
            enabled: widget.trackImpressions,
            child: _WeeklyEventCard(
              key: ValueKey<String>('weekly-event-${event.id}'),
              event: event,
              compactTitle: compactTitle,
              canOpen: () => mounted && _inCurrentWeek(event),
            ),
          );
        },
      ),
    );
  }
}
