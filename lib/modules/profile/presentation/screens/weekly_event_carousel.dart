import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import 'weekly_event_detail_screen.dart';

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
      height: 88,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final event = items[index];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: AppColors.coral.withValues(alpha: 0.22),
            highlightColor: Colors.white.withValues(alpha: 0.05),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WeeklyEventDetailScreen(event: event),
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              child: Ink(
                width: 170,
                padding: EdgeInsets.all(compactTitle ? 8 : 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.inputFill, AppColors.navBlueSoft],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 50,
                        child: event.imageAssetPath != null
                            ? Image.asset(
                                event.imageAssetPath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _placeholder(),
                              )
                            : _placeholder(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            event.title,
                            maxLines: compactTitle ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          SizedBox(height: compactTitle ? 4 : 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: AppColors.coralAlt,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${event.eventDate} - ${event.startTime}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: compactTitle ? 11 : 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: compactTitle ? 2 : 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.music_note_outlined,
                                size: 13,
                                color: AppColors.coralAlt,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  event.artistName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: compactTitle ? 11 : 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.navBlueSoft,
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
    );
  }
}
