import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_consent_controller.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/presentation/widgets/analytics_preference_entry.dart';
import 'package:soundconnect_23_12_25codx/modules/auth/presentation/widgets/registration_options_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/analytics_consent.dart';

void main() {
  late TestAnalyticsConsent controller;
  setUp(() {
    controller = TestAnalyticsConsent();
    serviceLocator.registerSingleton<AnalyticsConsentController>(controller);
  });
  tearDown(() async {
    await serviceLocator.unregister<AnalyticsConsentController>();
    controller.dispose();
  });

  Future<void> mount(WidgetTester tester, Widget entry) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: entry)));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'guest can read each notice without recording a choice, decline and change later',
    (tester) async {
      await mount(tester, const GuestAnalyticsPreferenceEntry());
      expect(find.text('Kullanım istatistiklerine izin ver'), findsOneWidget);
      await tester.tap(find.text('Detaylar'));
      await tester.pumpAndSettle();
      for (final doc in [
        ('Analitik aydınlatma metni', 'Analitik aydınlatma metni'),
        (
          'Analitik açık rıza metni',
          'Analitik ve Kullanım Verilerinin İşlenmesine İlişkin Açık Rıza',
        ),
        (
          'Genel KVKK aydınlatma metni',
          'SoundConnect – Kişisel Verilerin İşlenmesine İlişkin Aydınlatma Metni',
        ),
      ]) {
        await tester.tap(find.text(doc.$1));
        await tester.pumpAndSettle();
        expect(find.text(doc.$2), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(controller.decisions, isEmpty);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hayır'));
      await tester.pumpAndSettle();
      expect(find.text('Hayır'), findsNothing);
      await tester.tap(find.text('Gizlilik ve analitik tercihi'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kullanım istatistiklerine izin vermediniz.'),
        findsOneWidget,
      );
      expect(find.text('İzin veriyorum'), findsNothing);
      await tester.tap(find.text('Tercihimi değiştir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('İzin veriyorum'));
      await tester.pumpAndSettle();
      expect(controller.decisions, [false, true]);
      expect(
        find.text('Kullanım istatistiklerine izin verdiniz.'),
        findsOneWidget,
      );
      expect(find.text('İzin vermiyorum'), findsNothing);
    },
  );

  testWidgets(
    'consent card follows the entry width with equal choices and centered details',
    (tester) async {
      await mount(
        tester,
        const SizedBox(width: 320, child: GuestAnalyticsPreferenceEntry()),
      );
      final card = find.byKey(const Key('analytics-preference-card'));
      final container = tester.widget<Container>(card);
      expect(container.margin, const EdgeInsets.only(top: 16));
      final yes = find.widgetWithText(TextButton, 'Evet');
      final no = find.widgetWithText(TextButton, 'Hayır');
      expect(tester.getSize(card).width, 320);
      expect(tester.getSize(yes).width, tester.getSize(no).width);
      expect(
        tester.getCenter(find.text('Detaylar')).dx,
        closeTo(tester.getCenter(card).dx, .1),
      );
      expect(
        tester.getCenter(find.text('Detaylar')).dy,
        greaterThan(tester.getCenter(no).dy),
      );
    },
  );

  testWidgets(
    'registration shares the guest choice without starting registration',
    (tester) async {
      await mount(
        tester,
        Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => openRegistrationOptions(context),
                child: const Text('Aç'),
              ),
              const GuestAnalyticsPreferenceEntry(),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const Key('registration-options-sheet'));
      await tester.tap(find.descendant(of: sheet, matching: find.text('Evet')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('Gizlilik ve analitik tercihi'),
        ),
        findsOneWidget,
      );
      expect(controller.decisions, [true]);
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(find.text('Gizlilik ve analitik tercihi'), findsOneWidget);
    },
  );

  testWidgets(
    'closing the card records a single refusal on the current guest',
    (tester) async {
      await mount(tester, const GuestAnalyticsPreferenceEntry());
      final close = find.byTooltip('Kapat ve izin verme');
      final closeSize = tester.getSize(close);
      expect(closeSize.width, greaterThanOrEqualTo(48));
      expect(closeSize.height, greaterThanOrEqualTo(48));
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(controller.decisions, [false]);
      expect(close, findsNothing);
      await tester.tap(find.text('Gizlilik ve analitik tercihi'));
      await tester.pumpAndSettle();
      expect(
        find.text('Kullanım istatistiklerine izin vermediniz.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(controller.decisions, [false]);
    },
  );

  testWidgets('undecided member can decline directly before using the switch', (
    tester,
  ) async {
    controller.changeMember();
    await mount(tester, const MemberAnalyticsPreferenceTile());
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.text('Kullanım istatistikleri'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('İzin vermiyorum'));
    await tester.pumpAndSettle();
    expect(controller.decisions, [false]);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(controller.decisions, [false, true]);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'registration launches from an unscoped $brightness route with the app panel colors',
      (tester) async {
        final dark = brightness == Brightness.dark;
        final theme = dark ? AppTheme.navy : AppTheme.light;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => openRegistrationOptions(context),
                  child: const Text('Üye Ol'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Üye Ol'));
        await tester.pumpAndSettle();
        final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
        expect(
          sheet.backgroundColor,
          dark ? const Color(0xff050910) : theme.scaffoldBackgroundColor,
        );
        final buttonColor = dark
            ? const Color(0xff070b13)
            : theme.colorScheme.surfaceContainerHighest;
        final google = tester.widget<OutlinedButton>(
          find.byKey(const Key('registration-google')),
        );
        expect(google.style!.backgroundColor!.resolve({}), buttonColor);
        final email = tester.widget<Material>(
          find
              .ancestor(
                of: find.byKey(const Key('registration-email-continue')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(email.color, buttonColor);
        final card = tester.widget<Container>(
          find.byKey(const Key('analytics-preference-card')),
        );
        expect(
          (card.decoration! as BoxDecoration).color!.toARGB32(),
          (dark ? const Color(0xff080d17) : theme.colorScheme.surface)
              .withValues(alpha: .40)
              .toARGB32(),
        );
      },
    );
  }

  testWidgets('an open preference screen cannot update a replacement account', (
    tester,
  ) async {
    await mount(tester, const GuestAnalyticsPreferenceEntry());
    await tester.tap(find.text('Detaylar'));
    await tester.pumpAndSettle();
    controller.changeMember();
    await tester.pumpAndSettle();
    expect(find.text('Oturum değişti.'), findsOneWidget);
    await tester.tap(find.text('İzin veriyorum'));
    await tester.pumpAndSettle();
    expect(controller.decisions, isEmpty);
  });
}
