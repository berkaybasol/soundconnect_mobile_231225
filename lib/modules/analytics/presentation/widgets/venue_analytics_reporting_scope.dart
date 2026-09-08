import 'package:flutter/widgets.dart';

import '../../domain/venue_analytics_reporting_config.dart';

/// Explicit test/host override. Place above the Navigator to cover nested routes.
class VenueAnalyticsReportingScope extends InheritedWidget {
  const VenueAnalyticsReportingScope({
    super.key,
    required this.config,
    required super.child,
  });

  final VenueAnalyticsReportingConfig config;

  static VenueAnalyticsReportingConfig of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<VenueAnalyticsReportingScope>()
          ?.config ??
      VenueAnalyticsReportingConfig.build;

  /// Callbacks and initial state use a non-subscribing read.
  static VenueAnalyticsReportingConfig read(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<VenueAnalyticsReportingScope>()
          ?.config ??
      VenueAnalyticsReportingConfig.build;

  @override
  bool updateShouldNotify(VenueAnalyticsReportingScope oldWidget) =>
      config.enabled != oldWidget.config.enabled;
}
