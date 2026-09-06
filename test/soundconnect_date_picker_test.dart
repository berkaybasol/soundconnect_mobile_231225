import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/soundconnect_date_picker.dart';

void main() {
  DateTime? result;
  var completed = false;

  Future<void> open(
    WidgetTester tester, {
    Brightness brightness = Brightness.dark,
    double scale = 1,
  }) async {
    result = null;
    completed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF47C7C),
            brightness: brightness,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSoundConnectDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 9, 6),
                  firstDate: DateTime(2026, 9, 1),
                  lastDate: DateTime(2027, 12, 31),
                  helpText: 'Etkinlik tarihi',
                );
                completed = true;
              },
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('Turkish calendar has navy surface and gradient action', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Etkinlik tarihi'), findsOneWidget);
    expect(find.text('Eylül 2026'), findsOneWidget);
    expect(find.text('Vazgeç'), findsOneWidget);
    expect(find.text('Seç'), findsOneWidget);
    expect(find.text('Select date'), findsNothing);
    final dialogContext = tester.element(find.byType(DatePickerDialog));
    final pickerTheme = DatePickerTheme.of(dialogContext);
    expect(pickerTheme.backgroundColor, const Color(0xFF101827));
    expect(pickerTheme.surfaceTintColor, Colors.transparent);
    expect(pickerTheme.confirmButtonStyle!.backgroundBuilder, isNotNull);
    expect(Localizations.localeOf(dialogContext).languageCode, 'tr');
    expect(
      Localizations.localeOf(tester.element(find.text('Aç'))).languageCode,
      'en',
    );
    await tester.tap(find.text('7'));
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 9, 7));
    expect(completed, isTrue);
  });

  testWidgets('cancel discards a changed selection', (tester) async {
    await open(tester);
    await tester.tap(find.text('7'));
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('Turkish date entry validates format and preserves range', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '01.08.2026');
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();
    expect(find.text('İzin verilen aralıktan bir tarih seç.'), findsOneWidget);
    expect(completed, isFalse);
    await tester.enterText(find.byType(TextFormField), '08.09.2026');
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2026, 9, 8));
  });

  testWidgets('year and month navigation retain native calendar behavior', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Eylül 2026'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027'));
    await tester.pumpAndSettle();
    expect(find.text('Eylül 2027'), findsOneWidget);
    await tester.tap(find.byTooltip('Gelecek ay'));
    await tester.pumpAndSettle();
    expect(find.text('Ekim 2027'), findsOneWidget);
    await tester.tap(find.text('8'));
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2027, 10, 8));
  });

  for (final brightness in Brightness.values) {
    testWidgets('compact 200 percent text fits in $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, brightness: brightness, scale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('Seç').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Seç'));
      await tester.pumpAndSettle();
      expect(result, DateTime(2026, 9, 6));
    });
  }
}
