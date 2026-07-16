import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_bottom_navigation.dart';

void main() {
  testWidgets('bottom navigation destination becomes the only root route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: <String, WidgetBuilder>{
          '/': (_) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/middle'),
                child: const Text('Open middle'),
              ),
            ),
          ),
          '/middle': (_) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => replaceProfileBottomNavigationRoute(
                  context,
                  '/destination',
                ),
                child: const Text('Switch tab'),
              ),
            ),
          ),
          '/destination': (_) => const Scaffold(body: Text('Destination')),
        },
      ),
    );

    await tester.tap(find.text('Open middle'));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);

    await tester.tap(find.text('Switch tab'));
    await tester.pumpAndSettle();

    expect(find.text('Destination'), findsOneWidget);
    expect(navigator.canPop(), isFalse);
  });
}
