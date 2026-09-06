part of 'guest_event_home_screen.dart';

extension _GuestEventCardNavigation on _EventCard {
  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WeeklyEventDetailScreen(
          event: WeeklyCalendarEvent(
            id: item.id,
            title: item.title,
            artistName: item.performerName,
            artistProfileId: item.musicianProfileId,
            bandProfileId: item.bandId,
            performerType: item.performerType,
            venueName: item.venueName,
            venueId: item.venueId,
            city: item.venueCity ?? '-',
            district: item.venueDistrict ?? '-',
            neighborhood: item.venueNeighborhood ?? '-',
            eventDate: _dateLabel(),
            startTime: item.startTime == null
                ? '--:--'
                : _formatTime(item.startTime!),
            endTime: item.endTime == null
                ? '--:--'
                : _formatTime(item.endTime!),
            imageAssetPath: item.posterImageUrl,
            description: item.description.trim(),
          ),
        ),
      ),
    );
  }
}
