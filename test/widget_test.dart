import 'package:flutter_test/flutter_test.dart';

import 'package:soundconnect_23_12_25codx/app/app.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';

void main() {
  setUpAll(setupDependencies);

  testWidgets('Login screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const SoundConnectApp());
    expect(find.text('Login'), findsOneWidget);
  });
}
