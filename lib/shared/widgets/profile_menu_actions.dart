import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../screens/support_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme_variant.dart';
import '../theme/theme_controller.dart';
import 'session_logout_action.dart';

const Key profileMenuThemeTileKey = Key('profile-menu-theme-tile');
const Key profileMenuSupportTileKey = Key('profile-menu-support-tile');

typedef ProfileQuickMenuAction = Future<void> Function();

class ProfileMenuLogo extends StatelessWidget {
  const ProfileMenuLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        'assets/logo.png',
        width: 34,
        height: 34,
        fit: BoxFit.cover,
      ),
    );
  }
}

Future<void> showProfileQuickMenu(
  BuildContext context, {
  required ProfileQuickMenuAction onSettings,
  required ProfileQuickMenuAction onManagement,
  ProfileQuickMenuAction? onProfileContact,
  Key? settingsTileKey,
  Key? profileContactTileKey,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: AppColors.pureBlack.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      Future<void> closeThen(ProfileQuickMenuAction action) async {
        Navigator.of(dialogContext).pop();
        await action();
      }

      return Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: 0.58,
          heightFactor: 1,
          child: Material(
            color: Theme.of(dialogContext).colorScheme.surface,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              left: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    ListTile(
                      key: settingsTileKey,
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Ayarlar'),
                      onTap: () async => closeThen(onSettings),
                    ),
                    if (onProfileContact != null)
                      ListTile(
                        key: profileContactTileKey,
                        leading: const Icon(Icons.badge_outlined),
                        title: const Text('Profil ve iletişim bilgileri'),
                        onTap: () async => closeThen(onProfileContact),
                      ),
                    ListTile(
                      leading: const Icon(Icons.dashboard_customize_outlined),
                      title: const Text('Yönetim Paneli'),
                      onTap: () async => closeThen(onManagement),
                    ),
                    ListTile(
                      key: profileMenuThemeTileKey,
                      leading: const Icon(Icons.palette_outlined),
                      title: const Text('Tema'),
                      onTap: () async =>
                          closeThen(() => showProfileMenuThemePicker(context)),
                    ),
                    ListTile(
                      key: profileMenuSupportTileKey,
                      leading: const Icon(Icons.support_agent_rounded),
                      title: const Text('Destek'),
                      onTap: () async =>
                          closeThen(() => showProfileMenuSupport(context)),
                    ),
                    const Spacer(),
                    SessionLogoutMenuTile(
                      onTap: () async {
                        Navigator.of(dialogContext).pop();
                        await confirmAndLogoutSession(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: Tween<double>(begin: 0, end: 1).animate(curved),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

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
