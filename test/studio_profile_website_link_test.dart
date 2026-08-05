import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/studio_profile_website_link.dart';

void main() {
  testWidgets('does not render an unsafe Studio website', (tester) async {
    await _pumpLink(tester, website: 'javascript:alert(1)');

    expect(find.byKey(const Key('studio-profile-website-link')), findsNothing);
  });

  testWidgets('renders and opens a safe Studio website', (tester) async {
    Uri? openedUri;
    await _pumpLink(
      tester,
      website: 'https://example.com/studio',
      launcher: (uri) async {
        openedUri = uri;
        return true;
      },
    );

    expect(find.text('example.com/studio'), findsOneWidget);
    await tester.tap(find.byKey(const Key('studio-profile-website-link')));
    await tester.pump();

    expect(openedUri, Uri.parse('https://example.com/studio'));
  });

  testWidgets('reports a website that cannot be opened', (tester) async {
    await _pumpLink(
      tester,
      website: 'https://example.com',
      launcher: (_) async => false,
    );

    await tester.tap(find.byKey(const Key('studio-profile-website-link')));
    await tester.pump();

    expect(find.text('Bağlantı açılamadı.'), findsOneWidget);
  });
}

Future<void> _pumpLink(
  WidgetTester tester, {
  required String website,
  StudioWebsiteLauncher? launcher,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StudioProfileWebsiteLink(website: website, launcher: launcher),
      ),
    ),
  );
}
