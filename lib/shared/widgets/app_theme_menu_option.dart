import 'package:flutter/material.dart';

/// Display options for the theme menus; only the original Koyu theme exists.
enum AppThemeMenuOption {
  light,
  dark,
  black;

  String get label => switch (this) {
    light => 'Açık (yakında)',
    dark => 'Koyu',
    black => 'Siyah (yakında)',
  };

  bool get isEnabled => this == dark;
  bool get isSelected => this == dark;

  IconData get icon => switch (this) {
    light => Icons.light_mode_outlined,
    dark => Icons.dark_mode_outlined,
    black => Icons.contrast_rounded,
  };
}
