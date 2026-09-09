import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_theme_menu_option.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/profile_menu_actions.dart';

void main() {
  testWidgets(
    'profile theme menu shows unavailable options and keeps Koyu selected',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProfileMenuThemePicker(context),
                child: const Text('Tema menüsünü aç'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tema menüsünü aç'));
      await tester.pumpAndSettle();

      for (final option in AppThemeMenuOption.values) {
        final finder = find.byKey(Key('profile-menu-theme-${option.name}'));
        final tile = tester.widget<ListTile>(finder);
        expect(
          find.descendant(of: finder, matching: find.text(option.label)),
          findsOneWidget,
        );
        expect(tile.enabled, option == AppThemeMenuOption.dark);
        if (option == AppThemeMenuOption.dark) {
          expect(tile.onTap, isNotNull);
          expect(
            find.descendant(
              of: finder,
              matching: find.byIcon(Icons.check_circle_rounded),
            ),
            findsOneWidget,
          );
        } else {
          expect(tile.onTap, isNull);
          expect(tile.trailing, isNull);
          await tester.tap(find.text(option.label));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(Theme.of(tester.element(finder)).brightness, Brightness.dark);
        }
      }
      await tester.tap(find.text('Koyu'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
      final original = AppTheme.navy;
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme, original.colorScheme);
      expect(theme.scaffoldBackgroundColor, original.scaffoldBackgroundColor);
      expect(
        theme.inputDecorationTheme.fillColor,
        original.inputDecorationTheme.fillColor,
      );
      expect(
        Theme.of(tester.element(find.text('Tema menüsünü aç'))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
