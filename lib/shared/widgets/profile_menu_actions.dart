import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../screens/support_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_variant.dart';
import '../theme/theme_controller.dart';

const Key profileMenuThemeTileKey = Key('profile-menu-theme-tile');
const Key profileMenuSupportTileKey = Key('profile-menu-support-tile');

IconData _themeIcon(AppThemeVariant variant) => switch (variant) {
  AppThemeVariant.light => Icons.light_mode_outlined,
  AppThemeVariant.dark => Icons.dark_mode_outlined,
  AppThemeVariant.black => Icons.contrast_rounded,
};

Future<void> showProfileMenuThemePicker(BuildContext context) async {
  if (!serviceLocator.isRegistered<ThemeController>()) return;
  final controller = serviceLocator<ThemeController>();
  final selected = await showModalBottomSheet<AppThemeVariant>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
            child: Text(
              'Tema seç',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          for (final variant in AppThemeVariant.values)
            ListTile(
              key: Key('profile-menu-theme-${variant.storageValue}'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(_themeIcon(variant)),
              title: Text(
                variant.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: controller.variant == variant
                  ? ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => LinearGradient(
                        colors: AppColors.brandGradient,
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.white,
                      ),
                    )
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(variant),
            ),
          const SizedBox(height: 12),
        ],
      );
    },
  );
  if (selected != null) await controller.setVariant(selected);
}

Future<void> showProfileMenuSupport(BuildContext context) async {
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SupportScreen()));
}
