import 'venue_event_item.dart';

/// Upcoming events and a count share the server's history boundary. History
/// rows are requested separately only when the owner opens that section.
class VenueEventManagementSnapshot {
  const VenueEventManagementSnapshot({
    required this.upcomingEvents,
    required this.pastCount,
    required this.historyAsOf,
  });

  final List<VenueOwnerEventItem> upcomingEvents;
  final int pastCount;
  final DateTime historyAsOf;
}

/// A bounded history page. The opaque cursor is valid only for its venue and
/// the snapshot's [VenueEventManagementSnapshot.historyAsOf] boundary.
class VenueEventHistoryPage {
  const VenueEventHistoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasNext,
  });

  final List<VenueOwnerEventItem> items;
  final String? nextCursor;
  final bool hasNext;
}
