import 'package:flutter/material.dart';
import '../../../analytics/presentation/section_navigation.dart';

import '../screens/studio_listener_info_screen.dart';

/// A studio detail can outlive the profile route beneath it. Give each pushed
/// surface its own audience boundary so cached studio data disappears as soon
/// as the viewer becomes a listener, including open sheets and dialogs.
WidgetBuilder studioRouteBoundary(WidgetBuilder builder) =>
    (_) => StudioListenerAccessGate(builder: builder);

MaterialPageRoute<T> studioPageRoute<T>({
  RouteSettings? settings,
  required WidgetBuilder builder,
}) => MaterialPageRoute<T>(
  settings: settings,
  builder: studioRouteBoundary(builder),
);

Future<T?> showStudioModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) => showModalBottomSheet<T>(
  context: context,
  routeSettings: const SectionRouteSettings(UsageSection.other),
  isScrollControlled: isScrollControlled,
  useSafeArea: useSafeArea,
  backgroundColor: backgroundColor,
  shape: shape,
  builder: studioRouteBoundary(builder),
);

Future<T?> showStudioDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showDialog<T>(
  context: context,
  routeSettings: const SectionRouteSettings(UsageSection.other),
  builder: studioRouteBoundary(builder),
);
