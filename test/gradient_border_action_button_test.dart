import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_border_action_button.dart';

void main() {
  testWidgets('gradient border action runs its enabled callback', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradientBorderActionButton(
            icon: Icons.cloud_upload_outlined,
            label: 'Yükle',
            onPressed: () => calls++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Yükle'));
    expect(calls, 1);
  });

  testWidgets('gradient border action disables taps while loading', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GradientBorderActionButton(
            icon: Icons.cloud_upload_outlined,
            label: 'Yükleniyor...',
            loading: true,
            onPressed: () => calls++,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Yükleniyor...'));
    expect(calls, 0);
  });
}
