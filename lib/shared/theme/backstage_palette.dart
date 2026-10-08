import 'package:flutter/material.dart';

/// Canonical neutral surfaces for SoundConnect's premium Backstage areas.
///
/// Feature modules may layer their own semantic accent colors on top of this
/// palette, but shared surfaces should keep these values in sync.
abstract final class BackstagePalette {
  static const canvasTop = Color(0xFF030713);
  static const canvas = Color(0xFF050910);
  static const canvasMid = Color(0xFF07101D);
  static const surface = Color(0xFF0B111D);
  static const surfaceRaised = Color(0xFF101722);
  static const input = Color(0xFF070B13);
  static const border = Color(0xFF202B3A);
  static const divider = Color(0xFF151D29);
  static const textPrimary = Color(0xFFEFF2F8);
  static const textMuted = Color(0xFF9EA8B7);
}
