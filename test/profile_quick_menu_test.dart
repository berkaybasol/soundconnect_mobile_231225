import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/profile_menu_actions.dart';

void main() {
  testWidgets('shared profile menu logo uses the SoundConnect asset', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ProfileMenuLogo())),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<AssetImage>());
    expect((image.image as AssetImage).assetName, 'assets/logo.png');
  });

  testWidgets('shared profile menu exposes and runs Studio contact action', (
    tester,
  ) async {
    var contactCalls = 0;
    await _pumpMenuLauncher(
      tester,
      onProfileContact: () async {
        contactCalls++;
      },
    );

    await tester.tap(find.byKey(const Key('open-profile-quick-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Ayarlar'), findsOneWidget);
    expect(find.text('Profil ve iletişim bilgileri'), findsOneWidget);
    expect(find.text('Yönetim Paneli'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Destek'), findsOneWidget);

    await tester.tap(find.text('Profil ve iletişim bilgileri'));
    await tester.pumpAndSettle();
    expect(contactCalls, 1);
  });

  testWidgets('shared profile menu omits unavailable contact action', (
    tester,
  ) async {
    await _pumpMenuLauncher(tester);

    await tester.tap(find.byKey(const Key('open-profile-quick-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Profil ve iletişim bilgileri'), findsNothing);
    expect(find.text('Yönetim Paneli'), findsOneWidget);
  });
}

Future<void> _pumpMenuLauncher(
  WidgetTester tester, {
  ProfileQuickMenuAction? onProfileContact,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: TextButton(
              key: const Key('open-profile-quick-menu'),
              onPressed: () => showProfileQuickMenu(
                context,
                onSettings: () async {},
                onManagement: () async {},
                onProfileContact: onProfileContact,
              ),
              child: const Text('Menüyü aç'),
            ),
          );
        },
      ),
    ),
  );
}
