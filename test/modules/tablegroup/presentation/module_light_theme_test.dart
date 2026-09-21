import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_design.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_game.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/domain/entities/table_group_profile_share.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/widgets/table_group_game_launcher_sheet.dart';
import 'package:soundconnect_23_12_25codx/modules/tablegroup/presentation/widgets/table_group_share_preview.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_controller.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/backstage_palette.dart';

void main() {
  final controller = AppThemeController.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await controller.setVariant(AppThemeVariant.dark);
  });

  tearDown(() async {
    await controller.setVariant(AppThemeVariant.dark);
  });

  testWidgets(
    'constant module children repaint without losing draft state or focus',
    (tester) async {
      await tester.pumpWidget(const _ThemeHarness(child: _DraftFixture()));
      await tester.enterText(find.byType(TextField), 'Taslağım burada kalsın');
      final editable = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      final darkGradient = TableGroupOverviewStyle.cardGradient;
      final darkShadows = TableGroupOverviewStyle.cardShadows;

      expect(_textColor(tester, 'Masa başlığı'), Colors.white);
      expect(_textColor(tester, 'DÜŞÜNCELER'), BackstagePalette.textMuted);
      expect(editable.widget.focusNode.hasFocus, isTrue);

      await tester.runAsync(() => controller.setVariant(AppThemeVariant.light));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byType(TextField))).brightness,
        Brightness.light,
      );
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(editable),
      );
      expect(editable.widget.controller.text, 'Taslağım burada kalsın');
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(
        _contrast(_textColor(tester, 'Masa başlığı'), AppColors.navBlue),
        greaterThan(4.5),
      );
      expect(
        _contrast(_textColor(tester, 'DÜŞÜNCELER'), AppColors.navBlue),
        greaterThan(4.5),
      );
      expect(
        TableGroupOverviewStyle.cardTop.computeLuminance(),
        greaterThan(.8),
      );
      expect(
        TableGroupOverviewStyle.cardBorder,
        isNot(TableGroupOverviewStyle.cardTop),
      );

      await tester.runAsync(() => controller.setVariant(AppThemeVariant.dark));
      await tester.pumpAndSettle();

      expect(TableGroupOverviewStyle.cardGradient, darkGradient);
      expect(TableGroupOverviewStyle.cardShadows, darkShadows);
      expect(_textColor(tester, 'Masa başlığı'), Colors.white);
      expect(_textColor(tester, 'DÜŞÜNCELER'), BackstagePalette.textMuted);
      expect(editable.widget.controller.text, 'Taslağım burada kalsın');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('open game sheet follows theme and keeps its selection action', (
    tester,
  ) async {
    TableGroupGameMode? result;
    await tester.pumpWidget(
      _ThemeHarness(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTableGroupGameLauncherSheet(context);
              },
              child: const Text('Oyunu aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Oyunu aç'));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey<String>('game-mode-dice'));
    final tileElement = tester.element(tile);
    final material = find
        .descendant(of: tile, matching: find.byType(Material))
        .first;
    expect(tester.widget<Material>(material).color, BackstagePalette.input);

    await tester.runAsync(() => controller.setVariant(AppThemeVariant.light));
    await tester.pumpAndSettle();

    expect(tester.element(tile), same(tileElement));
    final surface = tester.widget<Material>(material).color!;
    expect(surface.computeLuminance(), greaterThan(.8));
    expect(_contrast(_textColor(tester, 'Zar'), surface), greaterThan(4.5));
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(result, TableGroupGameMode.dice);
    expect(find.text('🎮 Hesap Kimde?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Color _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.color!;

double _contrast(Color first, Color second) {
  final a = first.computeLuminance();
  final b = second.computeLuminance();
  return ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05);
}

class _ThemeHarness extends StatelessWidget {
  const _ThemeHarness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: AppThemeController.instance,
    builder: (context, _) => MaterialApp(
      theme: AppTheme.current,
      themeAnimationDuration: Duration.zero,
      home: child,
    ),
  );
}

class _DraftFixture extends StatelessWidget {
  const _DraftFixture();

  @override
  Widget build(BuildContext context) => Theme(
    data: OverthinkingPalette.theme(context),
    child: const Scaffold(
      body: TableGroupOverviewBackdrop(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                OverthinkingSurface(child: OverthinkingEyebrow('DÜŞÜNCELER')),
                TextField(),
                TableGroupSharePreview(
                  table: TableGroupProfileShareSource(
                    id: 'test-table',
                    description: 'Masa başlığı',
                    venueName: 'Müzik masası',
                    cityName: 'İstanbul',
                    districtName: 'Kadıköy',
                    meetingAt: null,
                    expiresAt: null,
                    status: 'CANCELLED',
                    maxPersonCount: 4,
                    acceptedCount: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
