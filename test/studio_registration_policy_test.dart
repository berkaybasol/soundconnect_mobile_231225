import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/domain/studio_registration_policy.dart';

void main() {
  group('StudioRegistrationPolicy', () {
    test('matches Studio persistence boundaries', () {
      expect(
        StudioRegistrationPolicy.isValid(
          studioName: 's' * 100,
          studioAddress: 'a' * 255,
          phone: '05551234567',
        ),
        isTrue,
      );
      expect(
        StudioRegistrationPolicy.validationMessage(
          studioName: 's' * 101,
          studioAddress: 'a' * 255,
          phone: '05551234567',
        ),
        contains('100'),
      );
      expect(
        StudioRegistrationPolicy.validationMessage(
          studioName: 'Studio',
          studioAddress: 'a' * 256,
          phone: '05551234567',
        ),
        contains('255'),
      );
    });

    test('normalizes supported Turkish phone forms to eleven digits', () {
      expect(
        StudioRegistrationPolicy.normalizePhone('555 123 45 67'),
        '05551234567',
      );
      expect(
        StudioRegistrationPolicy.normalizePhone('+90 (555) 123-45-67'),
        '05551234567',
      );
      expect(
        StudioRegistrationPolicy.normalizePhone('05551234567'),
        '05551234567',
      );
    });

    test('rejects malformed or non-Turkish phone values', () {
      expect(StudioRegistrationPolicy.normalizePhone('0555-call-me'), isEmpty);
      expect(StudioRegistrationPolicy.normalizePhone('12345678901'), isEmpty);
      expect(StudioRegistrationPolicy.normalizePhone('555'), isEmpty);
    });
  });
}
