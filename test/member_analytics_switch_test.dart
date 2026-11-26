import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_consent_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/analytics_preference_entry.dart';

import 'support/analytics_consent.dart';

class _SavingConsent extends TestAnalyticsConsent {
  @override
  bool busy = false;

  void startSaving() {
    busy = true;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'member switch keeps accessible states, hit target and gestures',
    (tester) async {
      final controller = _SavingConsent()..changeMember();
      serviceLocator.registerSingleton<AnalyticsConsentController>(controller);
      addTearDown(() async {
        await serviceLocator.unregister<AnalyticsConsentController>();
        controller.dispose();
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MemberAnalyticsPreferenceTile()),
        ),
      );
      final control = find.byType(Switch);
      final bounds = tester.getSize(control);
      expect(bounds.width, greaterThanOrEqualTo(48));
      expect(bounds.height, greaterThanOrEqualTo(48));
      final initial = tester.getSemantics(control).getSemanticsData();
      expect(initial.label, 'Kullanım istatistikleri');
      expect(initial.flagsCollection.isToggled, Tristate.isFalse);
      expect(controller.choice, ConsentChoice.undecided);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(controller.decisions, [true]);
      expect(
        tester
            .getSemantics(control)
            .getSemanticsData()
            .flagsCollection
            .isToggled,
        Tristate.isTrue,
      );
      await tester.drag(control, const Offset(-36, 0));
      await tester.pumpAndSettle();
      expect(controller.decisions, [true, false]);

      controller.startSaving();
      await tester.pump();
      expect(tester.widget<Switch>(control).onChanged, isNull);
      expect(
        tester
            .getSemantics(control)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
    },
  );
}
