import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/event_invitation_rejection_dialog.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 560),
    const Size(844, 320),
  ]) {
    testWidgets('rejection dialog is concise and accessible at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final decisions = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(size.width == 390 ? 1 : 2),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: EventInvitationRejectionDialog(
              requestId: 'test',
              onDecision: decisions.add,
            ),
          ),
        ),
      );
      expect(
        find.text('Etkinlik davetini reddetmek istiyor musunuz?'),
        findsOneWidget,
      );
      expect(find.byType(Text), findsNWidgets(3));
      expect(decisions, isEmpty);
      final cancel = find.byKey(const Key('cancel-reject-test'));
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      await tester.tap(cancel);
      expect(decisions, [false]);
      final confirm = find.byKey(const Key('confirm-reject-test'));
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      expect(decisions, [false, true]);
      expect(tester.takeException(), isNull);
    });
  }
}
