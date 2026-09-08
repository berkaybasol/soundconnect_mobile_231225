import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../data/analytics_tracker.dart';
import 'analytics_exposure.dart';

/// Measurement belongs to the rendered surface, never repository prefetches.
class TrackEventImpression extends StatelessWidget {
  const TrackEventImpression({
    super.key,
    required this.eventId,
    required this.child,
    this.enabled = true,
  });

  final String eventId;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !serviceLocator.isRegistered<AnalyticsTracker>()) {
      return child;
    }
    return AnalyticsExposure(
      key: ValueKey('analytics-impression-$eventId'),
      enabled: eventId.trim().isNotEmpty,
      onExposed: () =>
          serviceLocator<AnalyticsTracker>().recordEventImpression(eventId),
      child: child,
    );
  }
}

class TrackEventDetailView extends StatelessWidget {
  const TrackEventDetailView({
    super.key,
    required this.eventId,
    required this.child,
    required this.enabled,
  });

  final String eventId;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!serviceLocator.isRegistered<AnalyticsTracker>()) return child;
    return AnalyticsExposure(
      key: ValueKey('analytics-detail-$eventId'),
      minimumVisibleDuration: Duration.zero,
      enabled: enabled && eventId.trim().isNotEmpty,
      onExposed: () =>
          serviceLocator<AnalyticsTracker>().recordEventDetailView(eventId),
      child: child,
    );
  }
}

class TrackVenueProfileView extends StatelessWidget {
  const TrackVenueProfileView({
    super.key,
    required this.venueId,
    required this.child,
    this.sourceEventId,
    this.enabled = true,
  });

  final String venueId;
  final String? sourceEventId;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!serviceLocator.isRegistered<AnalyticsTracker>()) return child;
    return AnalyticsExposure(
      key: ValueKey('analytics-venue-$venueId-$sourceEventId'),
      minimumVisibleDuration: Duration.zero,
      enabled: enabled && venueId.trim().isNotEmpty,
      onExposed: () => serviceLocator<AnalyticsTracker>()
          .recordVenueProfileView(venueId, sourceEventId: sourceEventId),
      child: child,
    );
  }
}
