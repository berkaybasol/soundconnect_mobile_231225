import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/profile_menu_actions.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/session_logout_action.dart';

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

  testWidgets('event invitations are no longer a quick-menu entry', (
    tester,
  ) async {
    await _pumpMenuLauncher(tester);
    await tester.tap(find.byKey(const Key('open-profile-quick-menu')));
    await tester.pumpAndSettle();
    expect(find.text('Etkinlik Onayları'), findsNothing);
    expect(find.text('Etkinlik Davetleri'), findsNothing);
    expect(find.text('Yönetim Paneli'), findsOneWidget);
  });

  testWidgets('shared profile menu remains scrollable on a short viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpMenuLauncher(
      tester,
      onProfileContact: () async {},
      textScaler: const TextScaler.linear(1.8),
    );

    await tester.tap(find.byKey(const Key('open-profile-quick-menu')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(sessionLogoutMenuTileKey),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(sessionLogoutMenuTileKey).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpMenuLauncher(
  WidgetTester tester, {
  ProfileQuickMenuAction? onProfileContact,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
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
