import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_colors.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/brand_gradient_icon.dart';

void main() {
  testWidgets(
    'studio social variant preserves icon size and accessible label',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BrandGradientIcon.social(
            Icons.location_on_outlined,
            size: 20,
            semanticLabel: 'Konum',
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.location_on_outlined));
      final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
      expect(icon.size, 20);
      expect(icon.color, AppColors.white);
      expect(mask.blendMode, BlendMode.srcIn);
      expect(mask.shaderCallback(const Rect.fromLTWH(0, 0, 20, 20)), isNotNull);
      expect(find.bySemanticsLabel('Konum'), findsOneWidget);
    },
  );

  testWidgets('brand gradient icon uses the complete SoundConnect gradient', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: BrandGradientIcon(
          Icons.add_circle_outline,
          semanticLabel: 'Spotify parçasını ekle',
        ),
      ),
    );

    final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));

    expect(mask.blendMode, BlendMode.srcIn);
    expect(
      BrandGradientIcon.gradient.colors,
      orderedEquals(AppColors.brandGradient),
    );
    expect(mask.shaderCallback(const Rect.fromLTWH(0, 0, 24, 24)), isNotNull);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    expect(find.bySemanticsLabel('Spotify parçasını ekle'), findsOneWidget);
  });
}
