import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_venue_support.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final venue in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'connection intro explains current flow, venue=$venue scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          bool? result;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.navy,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => venue
                              ? MusicianIntroScreen()
                              : VenueIntroScreen(),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.textContaining('Aktif Sanatçılar'), findsOneWidget);
          expect(find.textContaining('otomatik görünmez'), findsOneWidget);
          expect(find.textContaining('Ayarlar'), findsNothing);
          final navigation = find.textContaining('Yönetim Paneli →');
          await tester.ensureVisible(navigation);
          await tester.pumpAndSettle();
          expect(
            tester
                .getRect(navigation)
                .overlaps(tester.getRect(find.byType(SingleChildScrollView))),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          final button = tester.widget<GradientOutlineButton>(
            find.byType(GradientOutlineButton),
          );
          expect(button.strokeWidth, 1);
          await tester.tap(find.text('Anladım, devam et'));
          await tester.pumpAndSettle();
          expect(result, isTrue);
          expect(await shouldShowVenueConnectionIntro(), isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
