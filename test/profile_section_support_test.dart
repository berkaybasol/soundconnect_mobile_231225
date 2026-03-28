import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_section_support.dart';

void main() {
  group('profile section support widgets', () {
    testWidgets('renders section header title and action label', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProfileSectionHeader(title: 'Baslik', actionLabel: 'Duzenle'),
          ),
        ),
      );

      expect(find.text('Baslik'), findsOneWidget);
      expect(find.text('Duzenle'), findsOneWidget);
    });

    testWidgets('renders action buttons in non-owner mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileActionButtons(
              isFollowing: false,
              isEnabled: true,
              isLoading: false,
              ownerMode: false,
              onEditProfilePressed: () {},
              onFollowToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Takip Et'), findsOneWidget);
      expect(find.text('Mesaj Gonder'), findsOneWidget);
    });

    testWidgets('hides action buttons in owner mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileActionButtons(
              isFollowing: false,
              isEnabled: true,
              isLoading: false,
              ownerMode: true,
              onEditProfilePressed: () {},
              onFollowToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Takip Et'), findsNothing);
      expect(find.text('Mesaj Gonder'), findsNothing);
    });
  });
}
