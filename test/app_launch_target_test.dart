import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';

void main() {
  group('resolveLaunchTarget', () {
    test('returns guest when token is null or blank', () {
      expect(resolveLaunchTarget(null), AppLaunchTarget.guest);
      expect(resolveLaunchTarget(''), AppLaunchTarget.guest);
      expect(resolveLaunchTarget('   '), AppLaunchTarget.guest);
    });

    test('returns guest when token exists', () {
      expect(resolveLaunchTarget('token'), AppLaunchTarget.guest);
      expect(resolveLaunchTarget(' token '), AppLaunchTarget.guest);
    });
  });
}
