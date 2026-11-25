import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/admin_user_directory.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/pending_application.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/widgets/admin_user_detail_view.dart';

void main() {
  const userId = '8a1105c3-a2cd-4bbf-8f11-df7b84eca299';
  const publicCode = 'SC-3EBB0F1841584B83AC3A';

  testWidgets('active studio shows its profile and copies both identifiers', (
    tester,
  ) async {
    final copies = <(String, String)>[];
    var profileOpened = false;
    final detail = AdminUserDetail(
      account: const AdminUserAccount(
        userId: userId,
        username: 'mavioda',
        profileType: AdminUserProfileType.studio,
        status: AdminUserStatus.active,
      ),
      createdAt: DateTime(2026, 11, 23, 12),
      emailVerified: true,
      publicCode: publicCode,
      lastApplicationStatus: ApplicationReviewStatus.approved,
      profileId: '8e5cd13d-9e25-41fa-8c3a-a55af4f7467a',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUserDetailView(
            detail: detail,
            onOpenProfile: () => profileOpened = true,
            onCopy: (value, label) => copies.add((value, label)),
          ),
        ),
      ),
    );

    expect(find.text('23 Kasım 2026'), findsOneWidget);
    expect(find.text('Doğrulandı'), findsOneWidget);
    expect(find.text('Onaylandı'), findsOneWidget);
    for (final tooltip in [
      'Hesap kimliğini kopyala',
      'Kullanıcı kodunu kopyala',
    ]) {
      final button = find.byTooltip(tooltip);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }
    expect(copies, [(userId, 'Hesap kimliği'), (publicCode, 'Kullanıcı kodu')]);
    final open = find.text('Profili aç');
    await tester.ensureVisible(open);
    await tester.tap(open);
    expect(profileOpened, isTrue);
  });

  testWidgets(
    'rejected venue keeps its account status and handles missing dates on narrow screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const detail = AdminUserDetail(
        account: AdminUserAccount(
          userId: userId,
          username: 'kiyisahne',
          profileType: AdminUserProfileType.venue,
          status: AdminUserStatus.pendingVenueRequest,
        ),
        publicCode: publicCode,
        emailVerified: false,
        lastApplicationStatus: ApplicationReviewStatus.rejected,
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: AdminUserDetailView(
              detail: detail,
              onCopy: (_, _) {},
              onOpenProfile: () => fail('No profile exists'),
            ),
          ),
        ),
      );
      expect(find.text('Mekân adayı'), findsOneWidget);
      expect(find.text('Reddedildi'), findsOneWidget);
      expect(find.text('Kayıtlı değil'), findsOneWidget);
      expect(find.text('Doğrulanmadı'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('İşletme profili henüz oluşturulmadı.'),
        140,
      );
      expect(find.text('Profili aç'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
