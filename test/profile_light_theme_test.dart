import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_playlist_section.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_share_delete_dialog.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_room_photo_order_controls.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_data.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_controller.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppThemeController.instance.setVariant(AppThemeVariant.dark);
  });
  tearDown(() async {
    await AppThemeController.instance.setVariant(AppThemeVariant.dark);
  });

  testWidgets(
    'mounted playlist border repaints and keeps its action on theme changes',
    (tester) async {
      var edits = 0;
      final section = ListenerPlaylistSection(
        playlists: const [],
        onPlaylistTap: (_) {},
        onEdit: () => edits++,
        showWhenEmpty: true,
      );
      await tester.pumpWidget(_app(section));
      final finder = find.byKey(const Key('listener-playlist-empty-border'));
      final element = tester.element(finder);
      var previous = tester.widget<CustomPaint>(finder).foregroundPainter!;
      for (final variant in [AppThemeVariant.light, AppThemeVariant.dark]) {
        await _changeTheme(tester, variant);
        final current = tester.widget<CustomPaint>(finder).foregroundPainter!;
        expect(tester.element(finder), same(element));
        expect(current.shouldRepaint(previous), isTrue);
        await tester.tap(find.byKey(const Key('listener-playlist-empty-add')));
        previous = current;
      }
      expect(edits, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'listener publication theme changes without replacing editor state',
    (tester) async {
      const editor = ListenerProfileTheme(child: _DraftEditor());
      await tester.pumpWidget(_app(editor));
      final initialState = tester.state(find.byType(_DraftEditor));
      final initialTheme = Theme.of(tester.element(find.byType(TextFormField)));
      expect(initialTheme.brightness, Brightness.dark);
      expect(initialTheme.scaffoldBackgroundColor, listenerProfileDeepSurface);
      await tester.enterText(find.byType(TextFormField), 'Kaybolmayan taslak');

      await _changeTheme(tester, AppThemeVariant.light);
      expect(tester.state(find.byType(_DraftEditor)), same(initialState));
      expect(find.text('Kaybolmayan taslak'), findsOneWidget);
      final lightTheme = Theme.of(tester.element(find.byType(TextFormField)));
      expect(lightTheme.brightness, Brightness.light);
      expect(
        lightTheme.colorScheme.onSurface,
        AppTheme.light.colorScheme.onSurface,
      );

      await _changeTheme(tester, AppThemeVariant.dark);
      expect(tester.state(find.byType(_DraftEditor)), same(initialState));
      expect(find.text('Kaybolmayan taslak'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(TextFormField))).colorScheme,
        initialTheme.colorScheme,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mounted profile share dialog updates its surface and text', (
    tester,
  ) async {
    const dialog = ListenerShareDeleteDialog.event(confirmKey: Key('confirm'));
    await tester.pumpWidget(_app(dialog));
    final element = tester.element(find.byType(ListenerShareDeleteDialog));
    expect(
      tester.widget<Dialog>(find.byType(Dialog)).backgroundColor,
      listenerProfileSurface,
    );

    await _changeTheme(tester, AppThemeVariant.light);
    expect(
      tester.element(find.byType(ListenerShareDeleteDialog)),
      same(element),
    );
    final surface = tester.widget<Dialog>(find.byType(Dialog)).backgroundColor!;
    expect(surface.computeLuminance(), greaterThan(.85));
    final title = tester.widget<Text>(find.text('Paylaşımı kaldır?'));
    expect(title.style!.color!.computeLuminance(), lessThan(.2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('studio photo ordering remains usable after changing theme', (
    tester,
  ) async {
    int? moved;
    await tester.pumpWidget(
      _app(
        Center(
          child: StudioRoomPhotoOrderControls(
            index: 1,
            itemCount: 3,
            onMoveTo: (index) => moved = index,
          ),
        ),
      ),
    );
    await _changeTheme(tester, AppThemeVariant.light);
    await tester.tap(find.byKey(const Key('studio-room-photo-move-previous')));
    expect(moved, 0);
    final label = tester.widget<Text>(find.text('2/3'));
    expect(label.style!.color!.computeLuminance(), lessThan(.2));
    await _changeTheme(tester, AppThemeVariant.dark);
    await tester.tap(find.byKey(const Key('studio-room-photo-move-next')));
    expect(moved, 2);
    expect(tester.widget<Text>(find.text('2/3')).style!.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'event export keeps its original artwork palette in both themes',
    (tester) async {
      const card = EventShareCard(
        data: EventShareData(
          eventId: 'event-1',
          title: 'Konser',
          performerName: 'Müzisyen',
          performerLinked: false,
          venueName: 'Sahne',
          location: 'İstanbul',
        ),
      );
      await tester.pumpWidget(_app(const FittedBox(child: card)));
      final original = _gradientColors(tester);
      await _changeTheme(tester, AppThemeVariant.light);
      expect(_gradientColors(tester), original);
      expect(tester.takeException(), isNull);
    },
  );
}

List<List<Color>> _gradientColors(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(EventShareCard),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((widget) => widget.decoration)
    .whereType<BoxDecoration>()
    .where((decoration) => decoration.gradient != null)
    .map((decoration) => decoration.gradient!.colors)
    .toList();

Widget _app(Widget child) => ListenableBuilder(
  listenable: AppThemeController.instance,
  builder: (context, _) => MaterialApp(
    theme: AppTheme.current,
    themeAnimationDuration: Duration.zero,
    home: Scaffold(body: child),
  ),
);

Future<void> _changeTheme(WidgetTester tester, AppThemeVariant variant) async {
  await tester.runAsync(() => AppThemeController.instance.setVariant(variant));
  await tester.pumpAndSettle();
}

class _DraftEditor extends StatefulWidget {
  const _DraftEditor();
  @override
  State<_DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends State<_DraftEditor> {
  @override
  Widget build(BuildContext context) => TextFormField(initialValue: 'Taslak');
}
