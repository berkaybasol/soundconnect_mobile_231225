import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Turkish, 24-hour time selection regardless of the device's clock preference.
/// The override is limited to this route; selected hour/minute values and caller
/// themes are preserved without changing the app locale or any time zone.
Future<TimeOfDay?> showSoundConnectTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String helpText = 'Saat seç',
  TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
  TransitionBuilder? builder,
}) => showTimePicker(
  context: context,
  initialTime: initialTime,
  initialEntryMode: initialEntryMode,
  helpText: helpText,
  cancelText: 'Vazgeç',
  confirmText: 'Seç',
  errorInvalidText: 'Geçerli bir saat gir.',
  hourLabelText: 'Saat',
  minuteLabelText: 'Dakika',
  builder: (dialogContext, child) => Localizations.override(
    context: dialogContext,
    locale: const Locale('tr', 'TR'),
    delegates: GlobalMaterialLocalizations.delegates,
    child: MediaQuery(
      data: MediaQuery.of(dialogContext).copyWith(alwaysUse24HourFormat: true),
      child: Builder(
        builder: (scopedContext) =>
            builder?.call(scopedContext, child) ?? child!,
      ),
    ),
  ),
);
