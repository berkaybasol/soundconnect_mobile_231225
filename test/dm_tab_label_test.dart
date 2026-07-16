import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/screens/dm_tab_labels.dart';

void main() {
  testWidgets('primary messages tab shows a dot only for unread messages', (
    tester,
  ) async {
    Future<void> pumpLabel(int unreadCount) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: DmPrimaryMessagesTabLabel(unreadCount: unreadCount),
            ),
          ),
        ),
      );
    }

    await pumpLabel(0);
    expect(find.byKey(const Key('dm-primary-unread-dot')), findsNothing);

    await pumpLabel(4);
    expect(find.byKey(const Key('dm-primary-unread-dot')), findsOneWidget);
    expect(find.bySemanticsLabel('4 okunmamis birincil mesaj'), findsOneWidget);
  });
}
