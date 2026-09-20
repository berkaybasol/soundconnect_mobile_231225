import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/domain/marketplace_models.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/marketplace_access_gate.dart';
import 'package:soundconnect_23_12_25codx/modules/marketplace/presentation/marketplace_category_picker.dart';

import 'marketplace_test_support.dart';

const _guitars = 'guitars';
const _electric = 'electric-guitars';
const _classical = 'classical-guitars';
const _stage = 'stage-lighting';
const _lights = 'light-controllers';
const _stands = 'stage-stands';
const _categories = [
  MarketplaceCategory(
    id: _guitars,
    code: 'guitars',
    name: 'Gitarlar',
    children: [
      MarketplaceCategory(
        id: _electric,
        code: _electric,
        name: 'Elektro Gitarlar',
      ),
      MarketplaceCategory(
        id: _classical,
        code: _classical,
        name: 'Klasik Gitarlar',
      ),
    ],
  ),
  MarketplaceCategory(
    id: _stage,
    code: _stage,
    name: 'Sahne ve Işık',
    children: [
      MarketplaceCategory(
        id: _lights,
        code: _lights,
        name: 'Işık Kontrolcüleri',
      ),
      MarketplaceCategory(id: _stands, code: _stands, name: 'Sahne Standları'),
    ],
  ),
];

void main() {
  late MarketplaceTestSessions sessions;
  setUp(() async {
    await serviceLocator.reset();
    sessions = MarketplaceTestSessions(marketSession());
    serviceLocator.registerSingleton<AuthSessionManager>(
      sessions,
      dispose: (value) => value.dispose(),
    );
  });
  tearDown(() async => serviceLocator.reset());

  Future<_Selection> open(
    WidgetTester tester, {
    String? selectedId,
    String? initialRootId,
    bool leafOnly = false,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    final selection = _Selection();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: MarketplaceAccessGate(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  selection.value = await showMarketplaceCategoryPicker(
                    context,
                    categories: _categories,
                    selectedId: selectedId,
                    initialRootId: initialRootId,
                    leafOnly: leafOnly,
                  );
                  selection.completed = true;
                },
                child: const Text('Kategorileri aç'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Kategorileri aç'));
    await tester.pumpAndSettle();
    return selection;
  }

  testWidgets(
    'first level contains category groups without flattening their leaves',
    (tester) async {
      final selection = await open(tester);
      expect(find.text('Kategori seç'), findsOneWidget);
      expect(_row(_guitars), findsOneWidget);
      expect(_row(_stage), findsOneWidget);
      expect(_row(_electric), findsNothing);
      expect(_row(_classical), findsNothing);
      expect(_row(_lights), findsNothing);
      expect(selection.completed, isFalse);
      await tester.tap(find.byKey(const Key('marketplace-category-close')));
      await tester.pumpAndSettle();
      expect(selection.completed, isTrue);
      expect(selection.value, isNull);
    },
  );

  testWidgets(
    'entering a branch shows only its children and back returns to groups',
    (tester) async {
      final selection = await open(tester);
      await tester.tap(_row(_guitars));
      await tester.pumpAndSettle();
      expect(selection.completed, isFalse);
      expect(_row(_electric), findsOneWidget);
      expect(_row(_classical), findsOneWidget);
      expect(_row(_stage), findsNothing);
      expect(_row(_lights), findsNothing);
      await tester.tap(find.byKey(const Key('marketplace-category-back')));
      await tester.pumpAndSettle();
      expect(_row(_guitars), findsOneWidget);
      expect(_row(_stage), findsOneWidget);
      expect(_row(_electric), findsNothing);
      expect(selection.completed, isFalse);
    },
  );

  testWidgets(
    'group-wide selection returns its ID only after explicit branch action',
    (tester) async {
      final selection = await open(tester);
      await tester.tap(_row(_guitars));
      await tester.pumpAndSettle();
      expect(selection.completed, isFalse);
      await tester.tap(
        find.byKey(const Key('marketplace-category-branch-all')),
      );
      await tester.pumpAndSettle();
      expect(selection.completed, isTrue);
      expect(selection.value, _guitars);
    },
  );
  testWidgets(
    'Android back returns to groups first and only then cancels the picker',
    (tester) async {
      final selection = await open(tester, initialRootId: _guitars);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(selection.completed, isFalse);
      expect(_row(_guitars), findsOneWidget);
      expect(_row(_electric), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(selection.completed, isTrue);
      expect(selection.value, isNull);
      expect(find.text('Kategorileri aç'), findsOneWidget);
    },
  );

  testWidgets('leaf selection returns leaf ID rather than its group', (
    tester,
  ) async {
    final selection = await open(tester);
    await tester.tap(_row(_guitars));
    await tester.pumpAndSettle();
    await tester.tap(_row(_classical));
    await tester.pumpAndSettle();
    expect(selection.completed, isTrue);
    expect(selection.value, _classical);
  });

  testWidgets('all-categories selection is distinct from cancelling', (
    tester,
  ) async {
    final selection = await open(tester, selectedId: _classical);
    await tester.tap(find.byKey(const Key('marketplace-category-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('marketplace-category-all')));
    await tester.pumpAndSettle();
    expect(selection.completed, isTrue);
    expect(selection.value, '');
  });

  testWidgets('editor mode navigates groups but permits only leaf selection', (
    tester,
  ) async {
    final selection = await open(tester, leafOnly: true);
    expect(find.byKey(const Key('marketplace-category-all')), findsNothing);
    await tester.tap(_row(_stage));
    await tester.pumpAndSettle();
    expect(selection.completed, isFalse);
    expect(
      find.byKey(const Key('marketplace-category-branch-all')),
      findsNothing,
    );
    await tester.tap(_row(_lights));
    await tester.pumpAndSettle();
    expect(selection.value, _lights);
  });

  testWidgets(
    'global search finds a leaf with its parent context and Turkish folding',
    (tester) async {
      final selection = await open(tester);
      await tester.enterText(
        find.byKey(const Key('marketplace-category-search')),
        'isik kontrol',
      );
      await tester.pumpAndSettle();
      expect(_row(_lights), findsOneWidget);
      expect(find.text('Sahne ve Işık'), findsAtLeastNWidgets(1));
      expect(_row(_electric), findsNothing);
      await tester.tap(_row(_lights));
      await tester.pumpAndSettle();
      expect(selection.value, _lights);
    },
  );

  testWidgets('branch search stays in the chosen group', (tester) async {
    await open(tester, initialRootId: _guitars);
    await tester.enterText(
      find.byKey(const Key('marketplace-category-search')),
      'ışık',
    );
    await tester.pumpAndSettle();
    expect(_row(_lights), findsNothing);
    expect(_row(_electric), findsNothing);
    await tester.enterText(
      find.byKey(const Key('marketplace-category-search')),
      'klasik',
    );
    await tester.pumpAndSettle();
    expect(_row(_classical), findsOneWidget);
    expect(_row(_electric), findsNothing);
  });

  testWidgets('reopening a selected leaf restores the correct parent branch', (
    tester,
  ) async {
    final selection = await open(tester, selectedId: _stands);
    expect(_row(_stands), findsOneWidget);
    expect(_row(_lights), findsOneWidget);
    expect(_row(_electric), findsNothing);
    expect(find.byKey(const Key('marketplace-category-back')), findsOneWidget);
    await tester.tap(_row(_stands));
    await tester.pumpAndSettle();
    expect(selection.value, _stands);
  });

  testWidgets(
    'initial home group opens its branch without committing a filter',
    (tester) async {
      final selection = await open(tester, initialRootId: _stage);
      expect(_row(_lights), findsOneWidget);
      expect(_row(_stands), findsOneWidget);
      expect(selection.completed, isFalse);
      await tester.tap(find.byKey(const Key('marketplace-category-close')));
      await tester.pumpAndSettle();
      expect(selection.value, isNull);
    },
  );

  testWidgets(
    'short landscape viewport remains usable with keyboard and large text',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final selection = await open(
        tester,
        initialRootId: _guitars,
        textScaler: const TextScaler.linear(2),
      );
      expect(tester.takeException(), isNull);
      final search = find.byKey(const Key('marketplace-category-search'));
      await tester.ensureVisible(search);
      await tester.tap(search);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      await tester.enterText(search, 'klasik');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final scrollable = find
          .descendant(
            of: find.byType(MarketplaceCategoryPicker),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        _row(_classical),
        100,
        scrollable: scrollable,
      );
      expect(_row(_electric), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(selection.completed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        _row(_guitars),
        100,
        scrollable: scrollable,
      );
      await tester.tap(_row(_guitars));
      await tester.pumpAndSettle();
      expect(selection.completed, isFalse);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(selection.completed, isTrue);
      expect(selection.value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'same-frame selection after session replacement cannot commit a category',
    (tester) async {
      final selection = await open(tester, initialRootId: _guitars);
      sessions.replace(marketSession(userId: 'different-account'));
      // Deliberately do not pump the revoked gate before invoking the visible row.
      await tester.tap(_row(_electric));
      expect(selection.completed, isFalse);
      await tester.pumpAndSettle();
      expect(_row(_electric), findsNothing);
      await tester.tap(find.text('Geri dön').last);
      await tester.pumpAndSettle();
      expect(selection.completed, isTrue);
      expect(selection.value, isNull);
    },
  );

  testWidgets(
    'rapid leaf taps close only the picker and do not pop its parent',
    (tester) async {
      final selection = await open(tester, initialRootId: _guitars);
      final target = tester.getCenter(_row(_electric));
      await tester.tapAt(target);
      await tester.tapAt(target);
      await tester.pumpAndSettle();
      expect(selection.value, _electric);
      expect(find.text('Kategorileri aç'), findsOneWidget);
      expect(find.byType(MarketplaceCategoryPicker), findsNothing);
    },
  );
}

Finder _row(String id) => find.byKey(ValueKey('marketplace-category-$id'));

class _Selection {
  String? value;
  bool completed = false;
}
