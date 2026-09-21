import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/data/marketplace_report_admin_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/domain/marketplace_report_admin.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/marketplace_report_admin_screen.dart';

import 'marketplace_test_support.dart' show marketListingJson;
import 'support/event_audience_fakes.dart';

void main() {
  late AudienceTestSessions sessions;
  late _Repository repository;

  setUp(() {
    sessions = AudienceTestSessions(
      AuthSession.authenticated(
        token: 'moderator-token',
        userId: 'moderator-id',
        username: 'moderator',
        accountStatus: 'ACTIVE',
        roles: ['ROLE_ADMIN'],
        permissions: ['MANAGE_MARKETPLACE_REPORTS'],
        expiresAt: DateTime.utc(2100),
        isAdmin: true,
      ),
    );
    repository = _Repository(sessions);
  });
  tearDown(() => sessions.dispose());

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => MarketplaceReportAdminScreen(
                    repository: repository,
                    sessions: sessions,
                  ),
                ),
              ),
              child: const Text('Open reports'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open reports'));
    await tester.pumpAndSettle();
  }

  VoidCallback openReview(WidgetTester tester) => tester
      .widget<FilledButton>(
        find.widgetWithText(FilledButton, 'İncele ve karar ver'),
      )
      .onPressed!;

  FilledButton confirmButton(WidgetTester tester) => tester
      .widget<FilledButton>(find.widgetWithText(FilledButton, 'Kararı kaydet'));

  Future<VoidCallback> enterDecision(WidgetTester tester) async {
    openReview(tester)();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Karar gerekçesi  ');
    await tester.pump();
    return confirmButton(tester).onPressed!;
  }

  testWidgets('same-frame review openings create only one dialog', (
    tester,
  ) async {
    await mount(tester);
    final open = openReview(tester);
    open();
    open();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog, skipOffstage: false), findsOneWidget);
    expect(repository.reviews, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'repeated confirmation submits once and preserves reports route',
    (tester) async {
      await mount(tester);
      final confirm = await enterDecision(tester);
      confirm();
      confirm();
      await tester.pumpAndSettle();

      expect(find.text('Pazar şikâyetleri'), findsOneWidget);
      expect(repository.reviews, [(remove: false, note: 'Karar gerekçesi')]);
      expect(repository.loads, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('repeated cancellation preserves reports and releases the lock', (
    tester,
  ) async {
    await mount(tester);
    openReview(tester)();
    await tester.pumpAndSettle();
    final cancel = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Vazgeç'))
        .onPressed!;
    cancel();
    cancel();
    await tester.pumpAndSettle();

    expect(find.text('Pazar şikâyetleri'), findsOneWidget);
    expect(repository.reviews, isEmpty);
    expect(repository.loads, 1);
    openReview(tester)();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('barrier dismissal releases the lock and invalidates callbacks', (
    tester,
  ) async {
    await mount(tester);
    final staleConfirm = await enterDecision(tester);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    openReview(tester)();
    await tester.pumpAndSettle();
    staleConfirm();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repository.reviews, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'pending review blocks stale opens, refreshes and duplicate saves',
    (tester) async {
      final pending = Completer<Result<MarketplaceAdminReport>>();
      repository.onReview = () => pending.future;
      await mount(tester);
      final staleOpen = openReview(tester);
      final confirm = await enterDecision(tester);
      confirm();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      staleOpen();
      confirm();
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();

      expect(repository.reviews, hasLength(1));
      expect(repository.loads, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'İncele ve karar ver'),
            )
            .onPressed,
        isNull,
      );
      pending.complete(Result.success(repository.report));
      await tester.pumpAndSettle();
      expect(repository.loads, 2);
      openReview(tester)();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed review displays the error and permits a new decision', (
    tester,
  ) async {
    repository.onReview = () async => const Result.failure(
      AppError(code: 'unavailable', message: 'İşlem tamamlanamadı.'),
    );
    await mount(tester);
    (await enterDecision(tester))();
    await tester.pumpAndSettle();

    expect(find.text('İşlem tamamlanamadı.'), findsOneWidget);
    expect(repository.reviews, hasLength(1));
    expect(repository.loads, 2);
    repository.onReview = null;
    (await enterDecision(tester))();
    await tester.pumpAndSettle();
    expect(repository.reviews, hasLength(2));
    expect(repository.loads, 3);
    expect(find.text('Pazar şikâyetleri'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('session revocation invalidates a saved confirmation callback', (
    tester,
  ) async {
    await mount(tester);
    final confirm = await enterDecision(tester);
    final original = sessions.session;
    sessions.replace(const AuthSession.guest());
    sessions.replace(original);
    confirm();
    await tester.pumpAndSettle();

    expect(repository.reviews, isEmpty);
    expect(
      find.text('Oturumun değişti. İnceleme sayfasını yeniden aç.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(find.text('İnceleme yetkisi gerekli.'), findsOneWidget);
    expect(find.text('Pazar şikâyetleri'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('session revocation discards pending review completion', (
    tester,
  ) async {
    final pending = Completer<Result<MarketplaceAdminReport>>();
    repository.onReview = () => pending.future;
    await mount(tester);
    (await enterDecision(tester))();
    await tester.pump();
    expect(repository.reviews, hasLength(1));
    sessions.replace(const AuthSession.guest());
    pending.complete(
      const Result.failure(
        AppError(code: 'stale', message: 'Eski oturum yanıtı'),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.loads, 1);
    expect(find.text('İnceleme yetkisi gerekli.'), findsOneWidget);
    expect(find.text('Eski oturum yanıtı'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('emoji notes use Unicode code points for the minimum length', (
    tester,
  ) async {
    await mount(tester);
    openReview(tester)();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '🎸🎸🎸');
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '🎸🎸🎸🎸🎸');
    await tester.pump();
    confirmButton(tester).onPressed!();
    await tester.pumpAndSettle();

    expect(repository.reviews.single.note, '🎸🎸🎸🎸🎸');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('combined characters cannot exceed the note code point limit', (
    tester,
  ) async {
    await mount(tester);
    openReview(tester)();
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'e\u0301' * 501);
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNull);
    expect(find.text('En fazla 1000 karakter gir.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'e\u0301' * 500);
    await tester.pump();
    confirmButton(tester).onPressed!();
    await tester.pumpAndSettle();
    expect(repository.reviews.single.note, 'e\u0301' * 500);
    await tester.pumpWidget(const SizedBox());
  });
}

class _Api extends Fake implements ApiClient {}

typedef _Review = ({bool remove, String note});

class _Repository extends MarketplaceReportAdminRepository {
  _Repository(AudienceTestSessions sessions) : super(_Api(), sessions);

  final report = MarketplaceAdminReport.fromJson({
    'id': 'report-id',
    'version': 2,
    'status': 'OPEN',
    'reason': 'MISLEADING',
    'description': 'Ürün bilgisi yanlış.',
    'reportedAt': '2026-09-20T10:00:00Z',
    'evidence': marketListingJson()..['photos'] = [],
  });
  final reviews = <_Review>[];
  int loads = 0;
  Future<Result<MarketplaceAdminReport>> Function()? onReview;

  @override
  Future<Result<MarketplaceAdminReportPage>> load({
    String status = 'OPEN',
    int page = 0,
  }) async {
    loads++;
    return Result.success(
      MarketplaceAdminReportPage(items: [report], last: true),
    );
  }

  @override
  Future<Result<MarketplaceAdminReport>> review(
    MarketplaceAdminReport report, {
    required bool removeListing,
    required String note,
  }) async {
    reviews.add((remove: removeListing, note: note));
    if (onReview != null) return onReview!();
    return Result.success(report);
  }
}
