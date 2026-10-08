import 'package:flutter/material.dart';

import '../theme/app_theme_controller.dart';
import 'app_snack_bar.dart';

/// Shared selection state for both the login and profile theme menus.
enum AppThemeMenuOption {
  light,
  dark,
  black;

  String get label => switch (this) {
    light => 'Açık',
    dark => 'Koyu',
    black => 'Siyah (yakında)',
  };

  bool get isEnabled => this != black;
  bool get isSelected => this == selected;

  static AppThemeMenuOption get selected =>
      AppThemeController.instance.variant == AppThemeVariant.light
      ? light
      : dark;

  Future<void> select(BuildContext context) async {
    if (!isEnabled) return;
    final saved = await AppThemeController.instance.setVariant(
      this == light ? AppThemeVariant.light : AppThemeVariant.dark,
    );
    if (!saved && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        appSnackBar(
          context,
          tone: AppSnackBarTone.warning,
          content: const Text(
            'Tema değişti, ancak tercih cihaza kaydedilemedi.',
          ),
        ),
      );
    }
  }

  IconData get icon => switch (this) {
    light => Icons.light_mode_outlined,
    dark => Icons.dark_mode_outlined,
    black => Icons.contrast_rounded,
  };
}
