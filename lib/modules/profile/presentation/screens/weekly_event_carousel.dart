import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/venue_event_detail.dart';
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

  const WeeklyEventCarousel({
    super.key,
    required this.items,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.compactTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: SizedBox(
          height: 88,
          child: Center(
            child: Text(
              'Bu hafta icin etkinlik bulunamadi.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: compactTitle ? 244 : 256,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final event = items[index];
          return _WeeklyEventCard(event: event, compactTitle: compactTitle);
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navBlueSoft, AppColors.inputFill],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
    );
  }
}
