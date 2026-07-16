import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/app.dart';

void main() {
  group('resolveLaunchTarget', () {
    test('returns guest when token is null or blank', () {
      expect(resolveLaunchTarget(null), AppLaunchTarget.guest);
      expect(resolveLaunchTarget(''), AppLaunchTarget.guest);
      expect(resolveLaunchTarget('   '), AppLaunchTarget.guest);
    });

    test('returns guest when token is malformed', () {
      expect(resolveLaunchTarget('token'), AppLaunchTarget.guest);
      expect(resolveLaunchTarget(' token '), AppLaunchTarget.guest);
    });

    test('returns home only for a non-expiring JWT-shaped token', () {
      final now = DateTime.utc(2026, 7, 13, 8);
      expect(
        resolveLaunchTarget(
          _token(now.add(const Duration(minutes: 5))),
          now: now,
        ),
        AppLaunchTarget.home,
      );
      expect(
        resolveLaunchTarget(
          _token(now.add(const Duration(seconds: 10))),
          now: now,
        ),
        AppLaunchTarget.guest,
      );
    });
  });
}

String _token(DateTime expiresAt) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode(const {'alg': 'HS256'})}.'
      '${encode({'sub': 'user-id', 'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}.signature';
}
