import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'app_theme_runtime.dart';
import 'app_theme_variant.dart';

class ThemeController extends ChangeNotifier {
  static const String _themePrefKey = 'app_theme_variant';

  ThemeController._({
    required SharedPreferences? prefs,
    required AppThemeVariant variant,
  }) : _prefs = prefs,
       _variant = variant {
    AppThemeRuntime.setVariant(variant);
  }

  final SharedPreferences? _prefs;
  AppThemeVariant _variant;

  AppThemeVariant get variant => _variant;

  ThemeMode get themeMode =>
      _variant == AppThemeVariant.light ? ThemeMode.light : ThemeMode.dark;

  ThemeData get lightTheme => AppTheme.light;

  ThemeData get darkTheme => switch (_variant) {
    AppThemeVariant.black => AppTheme.black,
    _ => AppTheme.navy,
  };

  static Future<ThemeController> create() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themePrefKey);
    return ThemeController._(
      prefs: prefs,
      variant: parseAppThemeVariant(stored),
    );
  }

  factory ThemeController.memory({
    AppThemeVariant initial = AppThemeVariant.dark,
  }) {
    return ThemeController._(prefs: null, variant: initial);
  }

  Future<void> setVariant(AppThemeVariant next) async {
    if (_variant == next) return;
    _variant = next;
    AppThemeRuntime.setVariant(next);
    notifyListeners();
    await _prefs?.setString(_themePrefKey, next.storageValue);
  }
}
