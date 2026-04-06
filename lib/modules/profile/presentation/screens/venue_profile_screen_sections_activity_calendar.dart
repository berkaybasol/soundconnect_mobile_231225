// ignore_for_file: unused_element, unused_element_parameter, unused_local_variable, use_build_context_synchronously

part of 'venue_profile_screen.dart';

class _EventCalendarMock extends StatelessWidget {
  final List<WeeklyCalendarEvent> items;

  const _EventCalendarMock({required this.items});

  // ignore: unused_field
  static const List<WeeklyCalendarEvent> _items = [
    WeeklyCalendarEvent(
      id: 'venue-event-1',
      title: 'Acoustic Night',
      artistName: 'Luna Echo',
      artistProfileId: null,
      venueName: 'Sahne A',
      venueId: 'venue-1',
      city: 'Istanbul',
      district: 'Besiktas',
      neighborhood: 'Sinanpasa',
      eventDate: '28.03.2026',
      startTime: '20:30',
      endTime: '22:00',
      imageAssetPath: 'assets/logo.png',
      description: 'Haftalik akustik repertuvar gecesi.',
    ),
    WeeklyCalendarEvent(
      id: 'venue-event-2',
      title: 'DJ Session',
      artistName: 'Neon Tide',
      artistProfileId: null,
      venueName: 'Teras',
      venueId: 'venue-2',
      city: 'Istanbul',
      district: 'Kadikoy',
      neighborhood: 'Moda',
      eventDate: '29.03.2026',
      startTime: '22:00',
      endTime: '23:45',
      imageAssetPath: 'assets/logo.png',
      description: 'Elektronik set ve sahne gecisleri.',
    ),
    WeeklyCalendarEvent(
      id: 'venue-event-3',
      title: 'Open Mic',
      artistName: 'Aegean Collective',
      artistProfileId: null,
      venueName: 'Lounge',
      venueId: 'venue-3',
      city: 'Istanbul',
      district: 'Sisli',
      neighborhood: 'Nisantasi',
      eventDate: '30.03.2026',
      startTime: '19:00',
      endTime: '21:00',
      imageAssetPath: 'assets/logo.png',
      description: 'Acik mikrofon performans bulusmasi.',
    ),
  ];

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
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                padding: const EdgeInsets.all(8),
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
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.navBlueSoft,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              )
                            : Container(
                                color: AppColors.navBlueSoft,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: AppColors.textMuted,
                                ),
                              ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
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
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
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
}
