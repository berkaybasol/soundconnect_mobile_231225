enum AppThemeVariant { light, dark, black }

extension AppThemeVariantX on AppThemeVariant {
  String get storageValue => switch (this) {
    AppThemeVariant.light => 'light',
    AppThemeVariant.dark => 'dark',
    AppThemeVariant.black => 'black',
  };

  String get label => switch (this) {
    AppThemeVariant.light => 'Acik',
    AppThemeVariant.dark => 'Koyu',
    AppThemeVariant.black => 'Siyah',
  };
}

AppThemeVariant parseAppThemeVariant(String? raw) {
  return switch (raw?.trim().toLowerCase()) {
    'light' => AppThemeVariant.light,
    'black' => AppThemeVariant.black,
    _ => AppThemeVariant.dark,
  };
}
