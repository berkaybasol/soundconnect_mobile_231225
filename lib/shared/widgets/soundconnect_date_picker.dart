import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../theme/app_colors.dart';

/// Scoped localization and styling: opening this picker does not change the
/// app's locale, date limits, or Material's accessible calendar/input behavior.
Future<DateTime?> showSoundConnectDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String helpText = 'Tarih seç',
}) {
  final base = Theme.of(context);
  final dark = base.brightness == Brightness.dark;
  final surface = dark ? const Color(0xFF101827) : const Color(0xFFFAF8FC);
  final header = dark ? const Color(0xFF151F31) : const Color(0xFFF1EDF7);
  final ink = dark ? const Color(0xFFEFF2F8) : const Color(0xFF202536);
  final muted = dark ? const Color(0xFFA8B4C9) : const Color(0xFF626A7D);
  final border = dark ? const Color(0xFF2A3447) : const Color(0xFFDAD5E4);
  final accent = AppColors.brandGradient[1];
  final selectedInk = const Color(0xFF111827);
  final foreground = WidgetStateProperty.resolveWith<Color?>((states) {
    if (states.contains(WidgetState.disabled)) {
      return muted.withValues(alpha: 0.38);
    }
    return states.contains(WidgetState.selected) ? selectedInk : ink;
  });
  final selection = WidgetStateProperty.resolveWith<Color?>((states) {
    return states.contains(WidgetState.selected) ? accent : Colors.transparent;
  });
  final theme = base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: accent,
      onPrimary: selectedInk,
      secondary: AppColors.brandGradient.last,
      surface: surface,
      surfaceContainerHigh: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      outline: border,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: border),
      ),
      headerBackgroundColor: header,
      headerForegroundColor: ink,
      headerHeadlineStyle: TextStyle(
        color: ink,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      ),
      headerHelpStyle: TextStyle(
        color: muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      dividerColor: border,
      subHeaderForegroundColor: ink,
      weekdayStyle: TextStyle(color: muted, fontSize: 12),
      dayStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      dayForegroundColor: foreground,
      dayBackgroundColor: selection,
      yearForegroundColor: foreground,
      yearBackgroundColor: selection,
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? selectedInk : accent;
      }),
      todayBackgroundColor: selection,
      todayBorder: BorderSide(color: accent.withValues(alpha: 0.75)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: header,
        hintStyle: TextStyle(color: muted),
        labelStyle: TextStyle(color: muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent),
        ),
      ),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: muted,
        minimumSize: const Size(72, 48),
      ),
      confirmButtonStyle:
          TextButton.styleFrom(
            foregroundColor: ink,
            minimumSize: const Size(88, 48),
            textStyle: base.textTheme.labelLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ).copyWith(
            backgroundBuilder: (context, states, child) => CustomPaint(
              foregroundPainter: _DateActionOutline(AppColors.brandGradient),
              child: child,
            ),
          ),
    ),
  );
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: helpText,
    cancelText: 'Vazgeç',
    confirmText: 'Seç',
    fieldLabelText: 'Tarih',
    fieldHintText: 'gg.aa.yyyy',
    errorFormatText: 'Tarihi gg.aa.yyyy biçiminde gir.',
    errorInvalidText: 'İzin verilen aralıktan bir tarih seç.',
    builder: (dialogContext, child) => Localizations.override(
      context: dialogContext,
      locale: const Locale('tr', 'TR'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: Theme(data: theme, child: child!),
    ),
  );
}

class _DateActionOutline extends CustomPainter {
  const _DateActionOutline(this.colors);

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..shader = LinearGradient(colors: colors).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _DateActionOutline oldDelegate) =>
      oldDelegate.colors != colors;
}
