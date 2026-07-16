import 'package:flutter/widgets.dart';

/// Bottom-bar destinations are application roots, not drill-down pages.
/// Replacing the whole route history prevents every tab switch from adding a
/// stale screen to the back stack.
Future<T?> replaceProfileBottomNavigationRoute<T extends Object?>(
  BuildContext context,
  String routeName, {
  Object? arguments,
}) {
  return Navigator.of(
    context,
  ).pushNamedAndRemoveUntil<T>(routeName, (_) => false, arguments: arguments);
}
