import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/soundconnect_time_picker.dart';

void main() {
  for (final time in const [
    TimeOfDay(hour: 0, minute: 0),
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 21, minute: 5),
  ]) {
    testWidgets(
      'dial preserves ${time.hour}:${time.minute} without a day period',
      (tester) async {
        TimeOfDay? returned;
        await _open(
          tester,
          initial: time,
          onResult: (value) => returned = value,
        );
        final pickerContext = tester.element(find.byType(TimePickerDialog));
        expect(MediaQuery.of(pickerContext).alwaysUse24HourFormat, isTrue);
        expect(Localizations.localeOf(pickerContext), const Locale('tr', 'TR'));
        expect(find.text('AM'), findsNothing);
        expect(find.text('PM'), findsNothing);
        expect(find.text('ÖÖ'), findsNothing);
        expect(find.text('ÖS'), findsNothing);
        expect(find.text(time.hour.toString().padLeft(2, '0')), findsWidgets);
        expect(find.text(time.minute.toString().padLeft(2, '0')), findsWidgets);
        await tester.tap(find.text('Seç'));
        await tester.pumpAndSettle();
        expect(returned, time);
        final parent = tester.element(find.text('Saati seç'));
        expect(MediaQuery.of(parent).alwaysUse24HourFormat, isFalse);
        expect(Localizations.localeOf(parent).languageCode, 'en');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'keyboard accepts exact ${time.hour}:${time.minute} in 24-hour form',
      (tester) async {
        TimeOfDay? returned;
        await _open(
          tester,
          initial: const TimeOfDay(hour: 7, minute: 30),
          mode: TimePickerEntryMode.input,
          onResult: (value) => returned = value,
        );
        final fields = find.descendant(
          of: find.byType(TimePickerDialog),
          matching: find.byType(TextFormField),
        );
        expect(fields, findsNWidgets(2));
        await tester.enterText(
          fields.at(0),
          time.hour.toString().padLeft(2, '0'),
        );
        await tester.enterText(
          fields.at(1),
          time.minute.toString().padLeft(2, '0'),
        );
        await tester.tap(find.text('Seç'));
        await tester.pumpAndSettle();
        expect(returned, time);
        expect(find.byType(TimePickerDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'caller theme and media properties survive the route-only override',
    (tester) async {
      const sentinel = Color(0xFF16324F);
      MediaQueryData? nativeRouteMedia;
      await _open(
        tester,
        nativePicker: true,
        initial: const TimeOfDay(hour: 21, minute: 5),
        builder: (context, child) {
          nativeRouteMedia = MediaQuery.of(context);
          return child!;
        },
        onResult: (_) {},
      );
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      MediaQueryData? callerMedia;
      Locale? callerLocale;
      var completed = false;
      TimeOfDay? returned;
      await _open(
        tester,
        initial: const TimeOfDay(hour: 21, minute: 5),
        builder: (context, child) {
          callerMedia = MediaQuery.of(context);
          callerLocale = Localizations.localeOf(context);
          return Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: const TimePickerThemeData(
                dialBackgroundColor: sentinel,
              ),
            ),
            child: child!,
          );
        },
        onResult: (value) {
          completed = true;
          returned = value;
        },
      );
      final picker = tester.element(find.byType(TimePickerDialog));
      expect(callerLocale, const Locale('tr', 'TR'));
      expect(callerMedia!.alwaysUse24HourFormat, isTrue);
      expect(callerMedia!.textScaler.scale(10), 13);
      // Compare with the same native dialog route: Scaffold / dialog layouts
      // may consume insets before the picker builder runs.
      expect(callerMedia!.viewInsets, nativeRouteMedia!.viewInsets);
      expect(callerMedia!.size, const Size(800, 600));
      expect(Theme.of(picker).timePickerTheme.dialBackgroundColor, sentinel);
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(returned, isNull);
      final parent = tester.element(find.byKey(const Key('time-picker-host')));
      expect(MediaQuery.of(parent).alwaysUse24HourFormat, isFalse);
      expect(MediaQuery.of(parent).textScaler.scale(10), 13);
      expect(MediaQuery.of(parent).viewInsets.bottom, 24);
      expect(Localizations.localeOf(parent).languageCode, 'en');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  required TimeOfDay initial,
  required ValueChanged<TimeOfDay?> onResult,
  TimePickerEntryMode mode = TimePickerEntryMode.dial,
  TransitionBuilder? builder,
  bool nativePicker = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 600);
  tester.view.viewInsets = const FakeViewPadding(bottom: 24);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en', 'US'),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          alwaysUse24HourFormat: false,
          textScaler: TextScaler.linear(1.3),
        ),
        child: child!,
      ),
      home: Builder(
        key: const Key('time-picker-host'),
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(
              await (nativePicker
                  ? showTimePicker(
                      context: context,
                      initialTime: initial,
                      initialEntryMode: mode,
                      builder: builder,
                      cancelText: 'Vazgeç',
                      confirmText: 'Seç',
                    )
                  : showSoundConnectTimePicker(
                      context: context,
                      initialTime: initial,
                      initialEntryMode: mode,
                      builder: builder,
                    )),
            ),
            child: const Text('Saati seç'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Saati seç'));
  await tester.pumpAndSettle();
}
