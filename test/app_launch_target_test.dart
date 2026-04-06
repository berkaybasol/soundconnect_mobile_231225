import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';

void main() {
  group('resolveLaunchTarget', () {
    test('returns login when token is null or blank', () {
      expect(resolveLaunchTarget(null), AppLaunchTarget.login);
      expect(resolveLaunchTarget(''), AppLaunchTarget.login);
      expect(resolveLaunchTarget('   '), AppLaunchTarget.login);
    });

    test('returns login when token exists', () {
      expect(resolveLaunchTarget('token'), AppLaunchTarget.login);
      expect(resolveLaunchTarget(' token '), AppLaunchTarget.login);
    });
  });
}
