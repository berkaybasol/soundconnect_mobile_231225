import 'package:flutter/widgets.dart';

import '../../../app/router/app_routes.dart';
import '../data/analytics_section.dart';
export '../data/analytics_section.dart';

/// Local route metadata. No route arguments, identifiers or free-form route
/// names are sent to Analytics.
class SectionRouteSettings extends RouteSettings {
  const SectionRouteSettings(this.section, {this.discoveryEvent = false})
    : inherit = false;
  const SectionRouteSettings.inherit()
    : section = UsageSection.other,
      inherit = true,
      discoveryEvent = false;
  final UsageSection section;
  final bool inherit;
  final bool discoveryEvent;
}

class SectionNavigation extends NavigatorObserver {
  SectionNavigation(this.onVisible);
  final void Function(SectionView) onVisible;
  final _views = Expando<SectionView>();
  Route<dynamic>? _top;
  bool _obscured = false;

  static void mark(BuildContext context, SectionView view) {
    final route = ModalRoute.of(context);
    final observers = route?.navigator?.widget.observers
        .whereType<SectionNavigation>();
    if (route == null || observers == null) return;
    for (final observer in observers) {
      if (observer._views[route] == view) continue;
      observer._views[route] = view;
      if (observer._top == route) observer._notify();
    }
  }

  void obscure(bool obscured) {
    if (obscured == _obscured) return;
    _obscured = obscured;
    _notify();
  }

  SectionView _resolve(Route<dynamic> route) {
    final known = _views[route];
    if (known != null) return known;
    final settings = route.settings;
    if (settings is SectionRouteSettings) {
      return sectionView(
        settings.section,
        discoveryEvent: settings.discoveryEvent,
      );
    }
    return switch (settings.name) {
      AppRoutes.tableGroupList => sectionView(
        UsageSection.tables,
        table: TableView.list,
      ),
      AppRoutes.tableGroupCreate => sectionView(
        UsageSection.tables,
        table: TableView.create,
      ),
      AppRoutes.tableGroupDetail => sectionView(
        UsageSection.tables,
        table: TableView.preview,
      ),
      AppRoutes.overthinkingFeed => sectionView(UsageSection.overthinking),
      AppRoutes.marketplace => sectionView(UsageSection.marketplace),
      AppRoutes.collabDiscovery => sectionView(UsageSection.collab),
      AppRoutes.eventDiscovery => sectionView(UsageSection.discover),
      AppRoutes.bandProfile ||
      AppRoutes.bandMemberProfile => profileView(ViewedProfile.band, true),
      AppRoutes.musicianProfile => profileView(ViewedProfile.musician, true),
      AppRoutes.listenerProfile => profileView(ViewedProfile.listener, true),
      AppRoutes.venueProfile => profileView(ViewedProfile.venue, true),
      AppRoutes.studioProfile => profileView(ViewedProfile.studio, true),
      // Public profile ownership/access checks run before the profile appears.
      // Only the resolved profile widget marks that view.
      _ => sectionView(UsageSection.other),
    };
  }

  static SectionView profileView(ViewedProfile kind, bool own) =>
      sectionView(UsageSection.profiles, profile: kind, own: own);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute == null) return;
    final settings = route.settings;
    if ((settings is SectionRouteSettings && settings.inherit) ||
        (route is PopupRoute &&
            settings.name == null &&
            settings is! SectionRouteSettings)) {
      _views[route] = _resolve(previousRoute);
    }
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _top = topRoute;
    _notify();
  }

  void _notify() {
    final top = _top;
    onVisible(
      _obscured || top == null
          ? sectionView(UsageSection.other)
          : _resolve(top),
    );
  }
}
