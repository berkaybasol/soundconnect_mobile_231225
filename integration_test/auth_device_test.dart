import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/login_screen_widget_test.dart' as login;

// Exercise the same login and signup widgets on Android. The suite keeps
// accounts, provider responses, and session storage in memory.
// Run the Google flows with:
// flutter test -d <emulator> --name Google integration_test/auth_device_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(binding.testTextInput.register);
  tearDown(binding.testTextInput.unregister);
  login.main();
}
