import 'package:flutter/material.dart';

import '../../../shared/theme/app_surface_theme.dart';

/// Shares Backstage's dark neutral surfaces with its profile routes.
/// Brand accents, component geometry, and the light theme stay inherited.
class ProfileVisualThemeScope extends StatelessWidget {
  const ProfileVisualThemeScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    // Keep the same widget structure when the theme changes so mounted editors
    // and profile state are preserved.
    return Theme(data: appSurfaceTheme(base), child: child);
  }
}
