/// Reporting availability is independent from analytics collection.
final class VenueAnalyticsReportingConfig {
  const VenueAnalyticsReportingConfig({required this.enabled});

  final bool enabled;

  static const build = VenueAnalyticsReportingConfig(
    enabled: bool.fromEnvironment(
      'SOUNDCONNECT_VENUE_ANALYTICS_REPORTING_ENABLED',
      defaultValue: false,
    ),
  );
}
