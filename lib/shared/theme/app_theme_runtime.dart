import 'app_theme_variant.dart';

class AppThemeRuntime {
  static AppThemeVariant _variant = AppThemeVariant.dark;

  static AppThemeVariant get variant => _variant;

  static void setVariant(AppThemeVariant variant) {
    _variant = variant;
  }
}
