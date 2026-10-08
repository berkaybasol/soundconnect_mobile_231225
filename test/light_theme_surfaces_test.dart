import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/theme/collab_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/widgets/collab_action_widgets.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/presentation/widgets/collab_discovery_widgets.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/dm_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/widgets/dm_visual_components.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_controller.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/ghost_profile_badge.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_border_action_button.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_text_field.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/soundconnect_date_picker.dart';

void main() {
  final controller = AppThemeController.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await controller.setVariant(AppThemeVariant.dark);
  });
  tearDown(() async => controller.setVariant(AppThemeVariant.dark));

  for (final scope in <String, Widget Function(Widget)>{
    'DM': (child) => DmVisualThemeScope(child: child),
    'Collab': (child) => CollabThemeScope(child: child),
    'Feed': (child) => MusicianFeedThemeScope(child: child),
  }.entries) {
    testWidgets('${scope.key} changes surfaces without replacing form state', (
      tester,
    ) async {
      final probeKey = GlobalKey<_FormProbeState>();
      final child = scope.value(_FormProbe(key: probeKey));
      await tester.pumpWidget(_ThemeHost(child: child));
      final originalState = probeKey.currentState!;
      final originalTheme = Theme.of(probeKey.currentContext!);
      await tester.enterText(find.byType(TextField), 'Yarım kalan taslak');
      await tester.tap(find.text('Sayacı artır'));
      await tester.pump();

      await tester.runAsync(() => controller.setVariant(AppThemeVariant.light));
      await tester.pumpAndSettle();
      expect(probeKey.currentState, same(originalState));
      expect(find.text('Yarım kalan taslak'), findsOneWidget);
      expect(find.text('Sayaç: 1'), findsOneWidget);
      final light = Theme.of(probeKey.currentContext!);
      expect(light.brightness, Brightness.light);
      expect(light.colorScheme.surface, AppTheme.light.colorScheme.surface);
      expect(
        light.inputDecorationTheme.fillColor!.computeLuminance(),
        greaterThan(.8),
      );
      expect(light.colorScheme.onSurface.computeLuminance(), lessThan(.1));
      expect(tester.takeException(), isNull);

      await tester.runAsync(() => controller.setVariant(AppThemeVariant.dark));
      await tester.pumpAndSettle();
      expect(probeKey.currentState, same(originalState));
      expect(find.text('Yarım kalan taslak'), findsOneWidget);
      final restored = Theme.of(probeKey.currentContext!);
      expect(restored.brightness, originalTheme.brightness);
      expect(restored.colorScheme, originalTheme.colorScheme);
      expect(restored.textTheme, originalTheme.textTheme);
      expect(
        restored.scaffoldBackgroundColor,
        originalTheme.scaffoldBackgroundColor,
      );
      expect(restored.canvasColor, originalTheme.canvasColor);
      expect(restored.dividerColor, originalTheme.dividerColor);
      expect(restored.inputDecorationTheme, originalTheme.inputDecorationTheme);
      expect(restored.appBarTheme, originalTheme.appBarTheme);
      expect(restored.cardTheme, originalTheme.cardTheme);
      expect(restored.dialogTheme, originalTheme.dialogTheme);
      expect(restored.bottomSheetTheme, originalTheme.bottomSheetTheme);
      expect(restored.popupMenuTheme, originalTheme.popupMenuTheme);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('light calendar keeps date bounds and selected date behavior', (
    tester,
  ) async {
    await tester.runAsync(() => controller.setVariant(AppThemeVariant.light));
    DateTime? selected;
    await tester.pumpWidget(
      _ThemeHost(
        child: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showSoundConnectDatePicker(
                  context: context,
                  initialDate: DateTime(2026, 9, 15),
                  firstDate: DateTime(2026, 9, 10),
                  lastDate: DateTime(2026, 9, 20),
                );
              },
              child: const Text('Takvim'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Takvim'));
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.byType(DatePickerDialog)));
    expect(theme.brightness, Brightness.light);
    expect(
      theme.datePickerTheme.backgroundColor!.computeLuminance(),
      greaterThan(.8),
    );
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate, DateTime(2026, 9, 10));
    expect(picker.lastDate, DateTime(2026, 9, 20));
    await tester.tap(find.text('Seç'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2026, 9, 15));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared controls stay legible across mounted theme changes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final textController = TextEditingController(
      text: 'Gitar, vokal ve yeni fikirler',
    );
    addTearDown(textController.dispose);
    await tester.pumpWidget(
      _ThemeHost(
        child: RepaintBoundary(
          key: boundaryKey,
          child: Scaffold(
            appBar: AppBar(title: const Text('SoundConnect')),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Birlikte müzik yapalım',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text('Akış, mesajlar ve iş birlikleri'),
                  const SizedBox(height: 24),
                  GradientTextField(
                    controller: textController,
                    label: 'Hakkında',
                    prefixIcon: Icons.music_note,
                  ),
                  const SizedBox(height: 20),
                  GradientBorderActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Profili düzenle',
                    onPressed: () {},
                  ),
                  const SizedBox(height: 12),
                  const GradientBorderActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Kaydediliyor',
                    onPressed: null,
                    loading: true,
                  ),
                  const SizedBox(height: 20),
                  CollabPrimaryAction(
                    label: 'İlan oluştur',
                    onPressed: () {},
                    icon: Icons.add,
                  ),
                  const SizedBox(height: 12),
                  const CollabPrimaryAction(
                    label: 'Başvuru kapalı',
                    onPressed: null,
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      CollabFeaturedPill(),
                      SizedBox(width: 12),
                      GhostProfileBadge(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const DmAvatar(size: 48, fallbackText: 'Deniz'),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Deniz\nBirlikte çalışmaya hazır',
                          style: TextStyle(height: 1.5),
                        ),
                      ),
                      DmHeaderAction(
                        icon: Icons.chat_outlined,
                        tooltip: 'Mesaj',
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    for (final variant in [
      AppThemeVariant.dark,
      AppThemeVariant.light,
      AppThemeVariant.dark,
    ]) {
      await tester.runAsync(() => controller.setVariant(variant));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final label = tester.widget<Text>(find.text('Profili düzenle'));
      final expected = variant == AppThemeVariant.light
          ? AppTheme.light.colorScheme.onSurface
          : Colors.white;
      expect(label.style!.color, expected);
      expect(find.text('Gitar, vokal ve yeni fikirler'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (Platform.environment['SOUNDCONNECT_THEME_SCREENSHOTS'] == '1') {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final output = File('build/theme-qa/controls-${variant.name}.png');
          await output.parent.create(recursive: true);
          await output.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }
  });
}

class _ThemeHost extends StatelessWidget {
  const _ThemeHost({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppThemeController.instance,
    builder: (context, _) => MaterialApp(
      theme: AppTheme.current,
      themeAnimationDuration: Duration.zero,
      home: child,
    ),
  );
}

class _FormProbe extends StatefulWidget {
  const _FormProbe({super.key});
  @override
  State<_FormProbe> createState() => _FormProbeState();
}

class _FormProbeState extends State<_FormProbe> {
  final controller = TextEditingController();
  int count = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          GradientTextField(
            controller: controller,
            label: 'Taslak',
            prefixIcon: Icons.edit,
          ),
          Text('Sayaç: $count', style: TextStyle(color: AppColors.textPrimary)),
          TextButton(
            onPressed: () => setState(() => count++),
            child: const Text('Sayacı artır'),
          ),
        ],
      ),
    );
  }
}
