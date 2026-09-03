import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/ghost_profile_badge.dart';

void main() {
  testWidgets('exposes a stable ghost-profile semantic label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GhostProfileBadge())),
    );

    expect(find.text('HAYALET PROFİL'), findsOneWidget);
    expect(find.bySemanticsLabel('Hayalet profil'), findsOneWidget);
  });

  testWidgets('supports icon-only compact contexts without losing semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GhostProfileBadge(showLabel: false)),
      ),
    );

    expect(find.text('HAYALET PROFİL'), findsNothing);
    expect(find.bySemanticsLabel('Hayalet profil'), findsOneWidget);
  });

  testWidgets('honors accessible text scaling without overflowing', (
    tester,
  ) async {
    Future<double> pumpAt(double scale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 700),
              textScaler: TextScaler.linear(scale),
            ),
            child: const Scaffold(body: Center(child: GhostProfileBadge())),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.text('HAYALET PROFİL')).height;
    }

    final normalHeight = await pumpAt(1);
    final scaledHeight = await pumpAt(2);

    expect(scaledHeight, greaterThan(normalHeight));
    expect(tester.takeException(), isNull);
  });
}
