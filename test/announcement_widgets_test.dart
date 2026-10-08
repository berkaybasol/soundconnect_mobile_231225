import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/analytics/data/analytics_tracker.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/media_gallery_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_access.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/entities/announcement.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/screens/announcement_editor_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/widgets/announcement_media.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'support/announcement_fixtures.dart';
import 'support/event_audience_fakes.dart';

void main() {
  setUp(() async => GetIt.instance.reset());
  tearDown(() async => GetIt.instance.reset());
  test('announcement management route requires exact permission', () {
    expect(
      AppRouteGuard.redirectFor(
        AppRoutes.adminAnnouncements,
        announcementAdminSession(),
      ),
      isNull,
    );
    expect(
      AppRouteGuard.redirectFor(
        AppRoutes.adminAnnouncements,
        announcementAdminSession(permitted: false),
      ),
      AppRoutes.adminDashboard,
    );
    expect(
      AppRouteGuard.redirectFor(
        AppRoutes.announcements,
        const AuthSession.guest(),
      ),
      AppRoutes.login,
    );
    expect(
      AppRouteGuard.redirectFor(AppRoutes.announcements, audienceSession()),
      isNull,
    );
  });
  testWidgets(
    'admin Flow Management entry checks permission again after dialog/menu rebuild',
    (tester) async {
      final sessions = AudienceTestSessions(announcementAdminSession());
      GetIt.instance.registerSingleton<AuthSessionManager>(
        sessions,
        dispose: (value) => value.dispose(),
      );
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: const AdminDashboardScreen(),
          onGenerateRoute: (settings) {
            opened.add(settings.name!);
            return MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('Announcement admin')),
            );
          },
        ),
      );
      await tester.tap(find.text('Akış Yönetimi'));
      await tester.pumpAndSettle();
      final entry = find.byKey(const Key('admin-announcements-entry'));
      expect(entry, findsOneWidget);
      final oldTap = tester.widget<ListTile>(entry).onTap!;
      sessions.replace(announcementAdminSession(permitted: false));
      oldTap();
      await tester.pump();
      expect(opened, isEmpty);
      expect(entry, findsNothing);
      sessions.replace(announcementAdminSession());
      await tester.pump();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(opened, [AppRoutes.adminAnnouncements]);
    },
  );
  testWidgets(
    'failed existing draft read cannot accidentally create a duplicate',
    (tester) async {
      final sessions = AudienceTestSessions(announcementAdminSession());
      addTearDown(sessions.dispose);
      final repository = AnnouncementTestRepository()
        ..onRead = (_, __) async => const Result.failure(
          AppError(code: 'network', message: 'Bağlantı hatası'),
        );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: AnnouncementEditorScreen(
            id: announcementFixtureId,
            repository: repository,
            sessions: sessions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Kayıtlı durumu yeniden yükle'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Kayıtlı durumu yeniden yükle'), findsOneWidget);
      final save = find.widgetWithText(FilledButton, 'Taslağı kaydet');
      await tester.scrollUntilVisible(
        save,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(repository.creates, 0);
    },
  );
  testWidgets(
    'pending draft save ignores duplicate taps and session revocation clears preview',
    (tester) async {
      final sessions = AudienceTestSessions(announcementAdminSession());
      addTearDown(sessions.dispose);
      final repository = _PendingCreateRepository();
      GetIt.instance.registerSingleton<ProfileMediaUploadRepository>(
        _Uploads(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: AnnouncementEditorScreen(
            repository: repository,
            sessions: sessions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Başlık');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Duyuru açıklaması',
      );
      final save = find.widgetWithText(FilledButton, 'Taslağı kaydet');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(repository.creates, 1);
      sessions.replace(const AuthSession.guest());
      await tester.pump();
      repository.pending.complete(Result.success(repository.current));
      await tester.pumpAndSettle();
      expect(find.text('SoundConnect yenilikleri'), findsNothing);
      expect(
        find.textContaining('Yetkin veya oturumun değişti'),
        findsOneWidget,
      );
      expect(GetIt.instance.isRegistered<AnalyticsTracker>(), isFalse);
    },
  );
  testWidgets(
    'known publication readiness rejection preserves the editable draft',
    (tester) async {
      final sessions = AudienceTestSessions(announcementAdminSession());
      addTearDown(sessions.dispose);
      final repository = _UnavailablePublishRepository();
      GetIt.instance.registerSingleton<ProfileMediaUploadRepository>(
        _Uploads(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.navy,
          home: AnnouncementEditorScreen(
            id: announcementFixtureId,
            repository: repository,
            sessions: sessions,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final publish = find.widgetWithText(FilledButton, 'Yayınla');
      await tester.scrollUntilVisible(
        publish,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(publish);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Onayla'));
      await tester.pumpAndSettle();
      expect(repository.publishes, 1);
      expect(repository.updates, 0);
      expect(tester.widget<FilledButton>(publish).onPressed, isNotNull);
      expect(find.text('Kayıtlı durumu yeniden yükle'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'real announcement feed card has per-item hide/directory/detail/engagement at ${scale}x text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final item = _feedItem();
        final actions = <String>[];
        final callbacks = MusicianFeedCardActions(
          openItem: (_) => actions.add('detail'),
          openAuthor: (_, __) {},
          toggleLike: (_) => actions.add('like'),
          openComments: (_) => actions.add('comments'),
          openLikes: (_) => actions.add('likes'),
          feedback: (_, action) => actions.add(action.apiValue),
          muteAuthor: (_, __) {},
          openCompletionTask: (_) {},
          openPromotion: (_) {},
          toggleCollabSaved: (_, __) {},
          followProfile: (_) {},
        );
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
              body: MusicianFeedThemeScope(
                child: Builder(
                  builder: (context) => SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MusicianFeedCardRegistry.standard().build(
                        context,
                        item,
                        callbacks,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            routes: {
              AppRoutes.announcements: (_) =>
                  const Scaffold(body: Text('Directory route')),
            },
          ),
        );
        expect(find.text('SoundConnect duyurusu'), findsOneWidget);
        expect(find.text('SoundConnect yenilikleri'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byTooltip('Bu duyuruyu akışta bir daha gösterme'),
        );
        expect(actions, ['HIDE']);
        await tester.ensureVisible(find.text('Duyuruyu aç'));
        await tester.tap(find.text('Duyuruyu aç'));
        expect(actions.last, 'detail');
        await tester.ensureVisible(find.text('Beğen'));
        await tester.tap(find.text('Beğen'));
        expect(actions.last, 'like');
        await tester.ensureVisible(find.text('Yorum'));
        await tester.tap(find.text('Yorum'));
        expect(actions.last, 'comments');
        await tester.ensureVisible(find.text('Tüm duyurular'));
        await tester.tap(find.text('Tüm duyurular'));
        await tester.pumpAndSettle();
        expect(find.text('Directory route'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'private media clears on logout and ignores stale access URL response',
    (tester) async {
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final repository = _Access();
      await tester.pumpWidget(
        MaterialApp(
          home: AnnouncementMediaView(
            media: Announcement.fromJson(
              announcementFixture(media: true),
            ).media!,
            repository: repository,
            sessions: sessions,
          ),
        ),
      );
      sessions.replace(const AuthSession.guest());
      await tester.pump();
      repository.pending.complete(
        Result.success(
          MediaAccess(
            assetId: announcementFixtureAssetId,
            accessUrl:
                'https://media.example.test/private.png?signature=temporary',
            expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 15)),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(AppCachedNetworkImage), findsNothing);
      expect(find.text('Medya erişimi sona erdi.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'background cancels expiring capability renewal; resume resolves once',
    (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final sessions = AudienceTestSessions(audienceSession());
      addTearDown(sessions.dispose);
      final repository = _ImmediateAccess();
      final media = Announcement.fromJson({
        ...announcementFixture(media: true),
        'media': {
          'assetId': announcementFixtureAssetId,
          'kind': 'VIDEO',
          'status': 'READY',
          'width': 1280,
          'height': 720,
        },
      }).media!;
      await tester.pumpWidget(
        MaterialApp(
          home: AnnouncementMediaView(
            media: media,
            repository: repository,
            sessions: sessions,
          ),
        ),
      );
      await tester.pump();
      expect(repository.reads, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 2));
      expect(repository.reads, 1);
      expect(find.byIcon(Icons.videocam_outlined), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(repository.reads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

MusicianFeedItem _feedItem() => MusicianFeedItem(
  id: 'ANNOUNCEMENT:$announcementFixtureId',
  type: MusicianFeedItemType.announcement,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 13),
  position: 0,
  impressionToken: 'opaque-real-delivery-proof',
  reason: const MusicianFeedReason(
    code: 'PLATFORM_ANNOUNCEMENT',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: const MusicianFeedTarget(
    type: 'ANNOUNCEMENT',
    id: announcementFixtureId,
  ),
  engagement: const MusicianFeedEngagement(
    targetType: 'ANNOUNCEMENT',
    targetId: announcementFixtureId,
    likeCount: 7,
    commentCount: 3,
    likedByMe: false,
    likable: true,
    commentable: true,
  ),
  promotion: null,
  feedbackCapabilities: const {MusicianFeedFeedbackAction.hide},
  payload: AnnouncementFeedPayload(
    Announcement.fromJson(announcementFixture()),
  ),
);

class _Uploads extends Fake implements ProfileMediaUploadRepository {
  @override
  void releaseDraftCleanupLeases(Iterable<String> assetIds) {}
}

class _Access extends Fake implements MediaGalleryRepository {
  final pending = Completer<Result<MediaAccess>>();
  @override
  Future<Result<MediaAccess>> getAccess(String assetId) => pending.future;
}

class _ImmediateAccess extends Fake implements MediaGalleryRepository {
  int reads = 0;
  @override
  Future<Result<MediaAccess>> getAccess(String assetId) async {
    reads++;
    return Result.success(
      MediaAccess(
        assetId: assetId,
        accessUrl: 'https://media.example.test/private.mp4',
        expiresAt: DateTime.now().toUtc().add(const Duration(seconds: 1)),
      ),
    );
  }
}

class _PendingCreateRepository extends AnnouncementTestRepository {
  final pending = Completer<Result<Announcement>>();
  @override
  Future<Result<Announcement>> createAnnouncement(AnnouncementWrite input) {
    creates++;
    return pending.future;
  }
}

class _UnavailablePublishRepository extends AnnouncementTestRepository {
  @override
  Future<Result<Announcement>> publishAnnouncement(
    String id, {
    required int expectedVersion,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    publishes++;
    return const Result.failure(
      AppError(code: '9913', message: 'İstatistikler şu anda kullanılamıyor.'),
    );
  }
}
