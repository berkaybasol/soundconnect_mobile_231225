import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    await AppThemeController.instance.setVariant(AppThemeVariant.dark);
  });

  test(
    'saved light survives a fresh controller and unknown values use original dark',
    () async {
      final controller = AppThemeController();
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.variant, AppThemeVariant.dark);
      expect(await controller.setVariant(AppThemeVariant.light), isTrue);
      final restored = AppThemeController();
      addTearDown(restored.dispose);
      await restored.initialize();
      expect(restored.variant, AppThemeVariant.light);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(AppThemeController.preferenceKey, 'black');
      final fallback = AppThemeController();
      addTearDown(fallback.dispose);
      await fallback.initialize();
      expect(fallback.variant, AppThemeVariant.dark);
    },
  );

  test(
    'rapid choices persist in order and loading cannot replace a new choice',
    () async {
      SharedPreferences.setMockInitialValues({
        AppThemeController.preferenceKey: 'light',
      });
      final loading = Completer<SharedPreferences>();
      final controller = AppThemeController(
        loadPreferences: () => loading.future,
      );
      addTearDown(controller.dispose);
      final initialization = controller.initialize();
      final light = controller.setVariant(AppThemeVariant.light);
      final dark = controller.setVariant(AppThemeVariant.dark);
      final preferences = await SharedPreferences.getInstance();
      loading.complete(preferences);
      await initialization;
      await Future.wait([light, dark]);
      expect(controller.variant, AppThemeVariant.dark);
      expect(preferences.getString(AppThemeController.preferenceKey), 'dark');
    },
  );

  test(
    'storage failure retains a usable theme and a later save recovers',
    () async {
      var fail = true;
      final controller = AppThemeController(
        loadPreferences: () async {
          if (fail) throw StateError('Storage unavailable');
          return SharedPreferences.getInstance();
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.variant, AppThemeVariant.dark);
      expect(await controller.setVariant(AppThemeVariant.light), isFalse);
      expect(controller.variant, AppThemeVariant.light);
      fail = false;
      expect(await controller.setVariant(AppThemeVariant.dark), isTrue);
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppThemeController.preferenceKey,
        ),
        'dark',
      );
    },
  );

  test(
    'dark ThemeData stays stable and light text and actions have readable contrast',
    () async {
      final original = AppTheme.navy;
      final originalPalette = AppColors.originalDark;
      await AppThemeController.instance.setVariant(AppThemeVariant.light);
      expect(AppTheme.navy, original);
      expect(AppColors.isLight, isTrue);
      final colors = AppColors.lightPalette;
      for (final surface in [
        colors.navBlue,
        colors.navBlueDeep,
        colors.navBlueSoft,
        colors.inputFill,
      ]) {
        for (final foreground in [
          colors.textPrimary,
          colors.textMuted,
          colors.coral,
        ]) {
          expect(
            _contrast(foreground, surface),
            greaterThanOrEqualTo(4.5),
            reason: 'Text $foreground on $surface',
          );
        }
      }
      for (final background in [
        colors.coralAlt,
        ...colors.brandGradient,
        ...AppColors.actionGradient,
        ...AppColors.actionSocialGradient,
      ]) {
        expect(
          _contrast(AppColors.onAccent, background),
          greaterThanOrEqualTo(4.5),
          reason: 'Action label on $background',
        );
      }
      for (final background in colors.spotifyGradient) {
        expect(
          _contrast(AppColors.onSpotify, background),
          greaterThanOrEqualTo(4.5),
        );
      }
      await AppThemeController.instance.setVariant(AppThemeVariant.dark);
      expect(AppColors.navBlue, originalPalette.navBlue);
      expect(AppColors.textPrimary, originalPalette.textPrimary);
      expect(AppColors.legacy(Colors.white70), Colors.white70);
      expect(AppTheme.current, original);
    },
  );
}

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}
