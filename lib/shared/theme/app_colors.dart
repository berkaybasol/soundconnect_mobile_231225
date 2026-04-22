import 'package:flutter/material.dart';

import 'app_theme_runtime.dart';
import 'app_theme_variant.dart';

class AppColors {
  static const white = Color(0xFFFFFFFF);
  static const pureBlack = Color(0xFF000000);

  static const _Palette _light = _Palette(
    black: Color(0xFFF8F5F6),
    navBlue: Color(0xFFF6F2F4),
    navBlueDeep: Color(0xFFFFFFFF),
    navBlueSoft: Color(0xFFF2EEF0),
    textPrimary: Color(0xFF1F2430),
    textMuted: Color(0xFF6B6268),
    border: Color(0xFFD7CCD1),
    inputFill: Color(0xFFEAE4E7),
    coral: Color(0xFFF47C7C),
    coralLight: Color(0xFFFFA6A6),
    peach: Color(0xFFFFC2A1),
    coralAlt: Color(0xFFEE7E7F),
    gradientA: Color(0xFFFF6B6B),
    gradientB: Color(0xFFFFC371),
    gradientC: Color(0xFFFF8FAB),
    brandGradient: [
      Color(0xFFF07A5E),
      Color(0xFFF06C86),
      Color(0xFFE062A9),
      Color(0xFFC15CE0),
      Color(0xFF9A58F4),
    ],
    spotifyGreen: Color(0xFF1DB954),
    spotifyGradient: [Color(0xFF1ED760), Color(0xFF1DB954), Color(0xFF18A34A)],
    socialGradient: [Color(0xFFFF7A3D), Color(0xFFEF5F86), Color(0xFFB85CFF)],
    neonPurpleGradient: [
      Color(0xFF7B2FF7),
      Color(0xFF9B5DE5),
      Color(0xFFC65BF0),
      Color(0xFFF26CA7),
      Color(0xFFFF7AA2),
      Color(0xFFB66DFF),
      Color(0xFF7B2FF7),
    ],
    musicianBlue: Color(0xFF1E5BD7),
  );

  static const _Palette _dark = _Palette(
    black: Color(0xFF0B0B10),
    navBlue: Color(0xFF101827),
    navBlueDeep: Color(0xFF0B1321),
    navBlueSoft: Color(0xFF1B2436),
    textPrimary: Color(0xFFEFF2F8),
    textMuted: Color(0xFFB7C0D0),
    border: Color(0xFF2A3447),
    inputFill: Color(0xFF151C2C),
    coral: Color(0xFFF47C7C),
    coralLight: Color(0xFFFFA6A6),
    peach: Color(0xFFFFC2A1),
    coralAlt: Color(0xFFEE7E7F),
    gradientA: Color(0xFFFF6B6B),
    gradientB: Color(0xFFFFC371),
    gradientC: Color(0xFFFF8FAB),
    brandGradient: [
      Color(0xFFF07A5E),
      Color(0xFFF06C86),
      Color(0xFFE062A9),
      Color(0xFFC15CE0),
      Color(0xFF9A58F4),
    ],
    spotifyGreen: Color(0xFF1DB954),
    spotifyGradient: [Color(0xFF1ED760), Color(0xFF1DB954), Color(0xFF18A34A)],
    socialGradient: [Color(0xFFFF7A3D), Color(0xFFEF5F86), Color(0xFFB85CFF)],
    neonPurpleGradient: [
      Color(0xFF7B2FF7),
      Color(0xFF9B5DE5),
      Color(0xFFC65BF0),
      Color(0xFFF26CA7),
      Color(0xFFFF7AA2),
      Color(0xFFB66DFF),
      Color(0xFF7B2FF7),
    ],
    musicianBlue: Color(0xFF1E5BD7),
  );

  static const _Palette _black = _Palette(
    black: Color(0xFF000000),
    navBlue: Color(0xFF000000),
    navBlueDeep: Color(0xFF000000),
    navBlueSoft: Color(0xFF0D0D0D),
    textPrimary: Color(0xFFEFF2F8),
    textMuted: Color(0xFF9B9B9B),
    border: Color(0xFF242424),
    inputFill: Color(0xFF141414),
    coral: Color(0xFFF47C7C),
    coralLight: Color(0xFFFFA6A6),
    peach: Color(0xFFFFC2A1),
    coralAlt: Color(0xFFEE7E7F),
    gradientA: Color(0xFFFF6B6B),
    gradientB: Color(0xFFFFC371),
    gradientC: Color(0xFFFF8FAB),
    brandGradient: [
      Color(0xFFF07A5E),
      Color(0xFFF06C86),
      Color(0xFFE062A9),
      Color(0xFFC15CE0),
      Color(0xFF9A58F4),
    ],
    spotifyGreen: Color(0xFF1DB954),
    spotifyGradient: [Color(0xFF1ED760), Color(0xFF1DB954), Color(0xFF18A34A)],
    socialGradient: [Color(0xFFFF7A3D), Color(0xFFEF5F86), Color(0xFFB85CFF)],
    neonPurpleGradient: [
      Color(0xFF7B2FF7),
      Color(0xFF9B5DE5),
      Color(0xFFC65BF0),
      Color(0xFFF26CA7),
      Color(0xFFFF7AA2),
      Color(0xFFB66DFF),
      Color(0xFF7B2FF7),
    ],
    musicianBlue: Color(0xFF1E5BD7),
  );

  static _Palette get _activePalette {
    return switch (AppThemeRuntime.variant) {
      AppThemeVariant.light => _light,
      AppThemeVariant.dark => _dark,
      AppThemeVariant.black => _black,
    };
  }

  static Color get black => _activePalette.black;
  static Color get navBlue => _activePalette.navBlue;
  static Color get navBlueDeep => _activePalette.navBlueDeep;
  static Color get navBlueSoft => _activePalette.navBlueSoft;
  static Color get textPrimary => _activePalette.textPrimary;
  static Color get textMuted => _activePalette.textMuted;
  static Color get border => _activePalette.border;
  static Color get inputFill => _activePalette.inputFill;
  static Color get coral => _activePalette.coral;
  static Color get coralLight => _activePalette.coralLight;
  static Color get peach => _activePalette.peach;
  static Color get coralAlt => _activePalette.coralAlt;
  static Color get gradientA => _activePalette.gradientA;
  static Color get gradientB => _activePalette.gradientB;
  static Color get gradientC => _activePalette.gradientC;
  static List<Color> get brandGradient => _activePalette.brandGradient;
  static Color get spotifyGreen => _activePalette.spotifyGreen;
  static Color get tableGroupApplyGreen => spotifyGreen;
  static List<Color> get spotifyGradient => _activePalette.spotifyGradient;
  static Color get spotifyGreenBright => _activePalette.spotifyGradient[0];
  static Color get spotifyGreenDark => _activePalette.spotifyGradient[2];
  static List<Color> get socialGradient => _activePalette.socialGradient;
  static Color get socialOrange => _activePalette.socialGradient[0];
  static Color get socialPink => _activePalette.socialGradient[1];
  static Color get socialPurple => _activePalette.socialGradient[2];
  static List<Color> get neonPurpleGradient =>
      _activePalette.neonPurpleGradient;
  static Color get musicianBlue => _activePalette.musicianBlue;
  static List<Color> get uploadCardGradient => [
    white.withValues(alpha: 0.10),
    brandGradient.last.withValues(alpha: 0.10),
    socialOrange.withValues(alpha: 0.10),
  ];
  static List<Color> get uploadedAudioCardGradient => uploadCardGradient;
}

class _Palette {
  const _Palette({
    required this.black,
    required this.navBlue,
    required this.navBlueDeep,
    required this.navBlueSoft,
    required this.textPrimary,
    required this.textMuted,
    required this.border,
    required this.inputFill,
    required this.coral,
    required this.coralLight,
    required this.peach,
    required this.coralAlt,
    required this.gradientA,
    required this.gradientB,
    required this.gradientC,
    required this.brandGradient,
    required this.spotifyGreen,
    required this.spotifyGradient,
    required this.socialGradient,
    required this.neonPurpleGradient,
    required this.musicianBlue,
  });

  final Color black;
  final Color navBlue;
  final Color navBlueDeep;
  final Color navBlueSoft;
  final Color textPrimary;
  final Color textMuted;
  final Color border;
  final Color inputFill;
  final Color coral;
  final Color coralLight;
  final Color peach;
  final Color coralAlt;
  final Color gradientA;
  final Color gradientB;
  final Color gradientC;
  final List<Color> brandGradient;
  final Color spotifyGreen;
  final List<Color> spotifyGradient;
  final List<Color> socialGradient;
  final List<Color> neonPurpleGradient;
  final Color musicianBlue;
}
