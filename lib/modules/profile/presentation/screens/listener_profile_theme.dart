import 'package:flutter/material.dart';

/// Existing publication and onboarding surfaces keep their local dark palette.
/// Profile chrome opts into the shared musician/venue application theme.
const listenerProfileDeepSurface = Color(0xFF070B13);
const listenerProfileChromeSurface = Color(0xFF111522);
const listenerProfileSurface = Color(0xFF101722);
const listenerProfileBorder = Color(0xFF202B3A);
const listenerProfileMuted = Color(0xFFA8B2C2);

ThemeData listenerProfileDarkTheme(BuildContext context) {
  final inherited = Theme.of(context);
  const scheme = ColorScheme.dark(
    primary: Color(0xFFF06C86),
    secondary: Color(0xFFC15CE0),
    surface: listenerProfileDeepSurface,
    onSurface: Colors.white,
    onSurfaceVariant: listenerProfileMuted,
    outline: listenerProfileBorder,
  );

  return inherited.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: listenerProfileDeepSurface,
    canvasColor: listenerProfileDeepSurface,
    dividerColor: listenerProfileBorder,
    textTheme: inherited.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    iconTheme: inherited.iconTheme.copyWith(color: scheme.onSurface),
    appBarTheme: inherited.appBarTheme.copyWith(
      backgroundColor: listenerProfileChromeSurface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomNavigationBarTheme: inherited.bottomNavigationBarTheme.copyWith(
      backgroundColor: listenerProfileChromeSurface,
      selectedItemColor: scheme.onSurface,
      unselectedItemColor: scheme.onSurfaceVariant,
    ),
  );
}

class ListenerProfileTheme extends StatelessWidget {
  const ListenerProfileTheme({
    super.key,
    required this.child,
    this.inheritAppTheme = false,
  });

  final Widget child;
  // Profile chrome shares the musician/venue palette. Existing publication and
  // onboarding surfaces retain their local palette unless explicitly opted in.
  final bool inheritAppTheme;

  @override
  Widget build(BuildContext context) {
    if (inheritAppTheme) return child;
    final theme = listenerProfileDarkTheme(context);
    return Theme(
      data: theme,
      // A nested Theme does not replace the enclosing Material's text style.
      // Keep publication text identical when this scope is inside a profile.
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium!,
        child: child,
      ),
    );
  }
}
