import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/city.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/district.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/entities/neighborhood.dart';
import 'package:soundconnect_23_12_25codx/modules/location/domain/location_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_preferences_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_opportunity_city_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/backstage_palette.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uses the Backstage palette and saves the newly selected city', (
    tester,
  ) async {
    const muddyGlobalSurface = Color(0xFF574534);
    final preferences = _PreferencesRepository();
    bool? changed;

    await _openSheet(
      tester,
      preferences: preferences,
      globalSurface: muddyGlobalSurface,
      onResult: (value) => changed = value,
    );

    final sheetContext = tester.element(
      find.byKey(const Key('musician-feed-opportunity-city-sheet')),
    );
    final sheetColors = Theme.of(sheetContext).colorScheme;
    expect(sheetColors.surface, BackstagePalette.canvas);
    expect(sheetColors.surfaceContainer, BackstagePalette.surface);
    expect(sheetColors.surfaceContainerHigh, BackstagePalette.surfaceRaised);
    expect(sheetColors.surfaceContainerHighest, BackstagePalette.input);
    expect(sheetColors.surface, isNot(muddyGlobalSurface));

    final istanbul = find.byKey(const Key('musician-feed-city-istanbul'));
    final ankara = find.byKey(const Key('musician-feed-city-ankara'));
    expect(
      find.descendant(of: istanbul, matching: find.text('Seçili')),
      findsOneWidget,
    );

    await tester.tap(ankara);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: ankara, matching: find.text('Seçili')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: istanbul, matching: find.text('Seçili')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('musician-feed-city-save')));
    await tester.pumpAndSettle();

    expect(preferences.updateCalls, [(cityId: 'ankara', expectedVersion: 7)]);
    expect(changed, isTrue);
    expect(
      find.byKey(const Key('musician-feed-opportunity-city-sheet')),
      findsNothing,
    );
  });

  testWidgets(
    'keeps save available at 360x640, 160 percent text, and keyboard inset',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final preferences = _PreferencesRepository();

      await _openSheet(tester, preferences: preferences, textScale: 1.6);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('musician-feed-city-search')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final save = find.byKey(const Key('musician-feed-city-save'));
      expect(save, findsOneWidget);
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(380));

      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(preferences.updateCalls, [
        (cityId: 'istanbul', expectedVersion: 7),
      ]);
    },
  );

  for (final scenario in [
    (size: const Size(390, 844), textScale: 1.0),
    (size: const Size(320, 640), textScale: 2.0),
  ]) {
    testWidgets(
      'keeps the focused editor and input connection through keyboard '
      'inset changes at ${scenario.size.width}dp and ${scenario.textScale}x text',
      (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);

        await _openSheet(
          tester,
          preferences: _PreferencesRepository(),
          textScale: scenario.textScale,
        );
        expect(tester.takeException(), isNull);
        final search = find.byKey(const Key('musician-feed-city-search'));
        final editable = find.descendant(
          of: search,
          matching: find.byType(EditableText),
        );
        await tester.tap(search);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final originalEditor = tester.state<EditableTextState>(editable);
        const composingValue = TextEditingValue(
          text: 'An',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        );
        tester.testTextInput.updateEditingValue(composingValue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Exercise normal -> compact -> normal, including intermediate
        // keyboard animation sizes. Large-text layouts start compact already.
        for (final inset in [80.0, 260.0, 0.0, 260.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: inset);
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            tester.state<EditableTextState>(editable),
            same(originalEditor),
          );
          expect(originalEditor.widget.focusNode.hasFocus, isTrue);
          expect(tester.testTextInput.hasAnyClients, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);
          expect(originalEditor.widget.controller.value, composingValue);
          expect(search.hitTestable(), findsOneWidget);
          final save = find.byKey(const Key('musician-feed-city-save'));
          expect(save.hitTestable(), findsOneWidget);
          expect(
            tester.getRect(save).bottom,
            lessThanOrEqualTo(scenario.size.height - inset),
          );
        }

        // Send text through the existing IME client, without refocusing the
        // field through tester.enterText (which would hide a lost-focus bug).
        tester.testTextInput.enterText('Ankara');
        await tester.pumpAndSettle();
        expect(originalEditor.widget.controller.text, 'Ankara');
        expect(
          find.byKey(const Key('musician-feed-city-ankara')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('musician-feed-city-istanbul')),
          findsNothing,
        );
        expect(find.byKey(const Key('musician-feed-city-izmir')), findsNothing);
        expect(originalEditor.widget.focusNode.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _openSheet(
  WidgetTester tester, {
  required _PreferencesRepository preferences,
  Color globalSurface = const Color(0xFF050910),
  double textScale = 1,
  ValueChanged<bool>? onResult,
}) async {
  final globalTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark().copyWith(surface: globalSurface),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: globalTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showMusicianFeedOpportunityCitySheet(
                context,
                preferencesRepository: preferences,
                locationRepository: const _LocationRepository(),
              );
              onResult?.call(result);
            },
            child: const Text('Şehir seçimini aç'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Şehir seçimini aç'));
  await tester.pumpAndSettle();
}

class _PreferencesRepository implements MusicianFeedPreferencesRepository {
  final updateCalls = <({String? cityId, int expectedVersion})>[];

  @override
  Future<Result<MusicianFeedPreferences>> get() async => const Result.success(
    MusicianFeedPreferences(
      contractVersion: 1,
      version: 7,
      opportunityCity: MusicianFeedPreferenceCity(
        id: 'istanbul',
        name: 'İstanbul',
      ),
      instruments: [],
    ),
  );

  @override
  Future<Result<MusicianFeedPreferences>> updateOpportunityCity({
    required String? cityId,
    required int expectedVersion,
  }) async {
    updateCalls.add((cityId: cityId, expectedVersion: expectedVersion));
    final cityName = cityId == 'ankara' ? 'Ankara' : 'İstanbul';
    return Result.success(
      MusicianFeedPreferences(
        contractVersion: 1,
        version: expectedVersion + 1,
        opportunityCity: cityId == null
            ? null
            : MusicianFeedPreferenceCity(id: cityId, name: cityName),
        instruments: const [],
      ),
    );
  }
}

class _LocationRepository implements LocationRepository {
  const _LocationRepository();

  @override
  Future<Result<List<City>>> getCities() async => const Result.success([
    City(id: 'istanbul', name: 'İstanbul'),
    City(id: 'ankara', name: 'Ankara'),
    City(id: 'izmir', name: 'İzmir'),
  ]);

  @override
  Future<Result<List<District>>> getDistricts(String cityId) =>
      throw UnimplementedError();

  @override
  Future<Result<List<Neighborhood>>> getNeighborhoods(String districtId) =>
      throw UnimplementedError();
}
