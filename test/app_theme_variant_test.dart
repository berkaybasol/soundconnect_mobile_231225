import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme_variant.dart';

void main() {
  group('parseAppThemeVariant', () {
    test('parses known values', () {
      expect(parseAppThemeVariant('light'), AppThemeVariant.light);
      expect(parseAppThemeVariant('dark'), AppThemeVariant.dark);
      expect(parseAppThemeVariant('black'), AppThemeVariant.black);
    });

    test('falls back to dark for unknown values', () {
      expect(parseAppThemeVariant('unknown'), AppThemeVariant.dark);
      expect(parseAppThemeVariant(null), AppThemeVariant.dark);
    });
  });
}
