import 'package:flutter/material.dart';

/// The listener profile artwork is deliberately a dark, premium surface in
/// every application theme. Keeping the local palette self-contained avoids
/// mixing a light app foreground with the dark profile cards when the user
/// switches themes while this route is open.
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
  const ListenerProfileTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(data: listenerProfileDarkTheme(context), child: child);
  }
}
