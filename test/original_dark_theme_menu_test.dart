import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_controller.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/app_theme_menu_option.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/profile_menu_actions.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeController.instance.setVariant(AppThemeVariant.dark);
  });
  tearDown(() async {
    await AppThemeController.instance.setVariant(AppThemeVariant.dark);
  });

  testWidgets('profile menu switches light and restores original Koyu', (
    tester,
  ) async {
    final originalDark = AppTheme.navy;
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: AppThemeController.instance,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.current,
          themeAnimationDuration: Duration.zero,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProfileMenuThemePicker(context),
                child: const Text('Tema menüsünü aç'),
              ),
            ),
          ),
        ),
      ),
    );
    Future<void> openMenu() async {
      await tester.tap(find.text('Tema menüsünü aç'));
      await tester.pumpAndSettle();
    }

    await openMenu();
    for (final option in AppThemeMenuOption.values) {
      final finder = find.byKey(Key('profile-menu-theme-${option.name}'));
      final tile = tester.widget<ListTile>(finder);
      expect(tile.enabled, option != AppThemeMenuOption.black);
      expect(tile.trailing != null, option == AppThemeMenuOption.dark);
    }
    await tester.tap(find.text('Siyah (yakında)'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Açık'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(
      Theme.of(tester.element(find.text('Tema menüsünü aç'))).brightness,
      Brightness.light,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(AppThemeController.preferenceKey), 'light');
    await openMenu();
    final selected = find.byKey(const Key('profile-menu-theme-light'));
    expect(
      find.descendant(
        of: selected,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Koyu'));
    await tester.pumpAndSettle();
    final theme = tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!;
    expect(theme, originalDark);
    expect(preferences.getString(AppThemeController.preferenceKey), 'dark');
    expect(tester.takeException(), isNull);
  });
}
