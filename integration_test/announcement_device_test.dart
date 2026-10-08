// Isolated device QA entry point. Never import this from lib/main.dart.
// Uses real widgets, RAM repositories and same-device fixture image transport.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/network_config.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/musician_feed_visual_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/widgets/musician_feed_card_registry.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/media_access.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/media_gallery_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/profile_media_upload_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/domain/entities/announcement.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/screens/announcement_directory_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/promotion/presentation/screens/announcement_editor_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import '../test/support/announcement_fixtures.dart';
import '../test/support/event_audience_fakes.dart';

const _fixtureBaseUrl = 'https://announcement-device.invalid';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('announcement actions directory and admin private-media lifecycle', (
    tester,
  ) async {
    binding.reportData = {
      'preflight': {'passed': false, 'required_base_url': _fixtureBaseUrl},
    };
    const configured = String.fromEnvironment('SOUNDCONNECT_BASE_URL');
    if (configured != _fixtureBaseUrl) {
      throw StateError(
        'This isolated QA entry point requires '
        '--dart-define=SOUNDCONNECT_BASE_URL=$_fixtureBaseUrl. Never use a real API URL.',
      );
    }
    expect(NetworkConfig.baseUrl, _fixtureBaseUrl);
    // This test covers form validation and dispatch, not Android IME behavior.
    // Keep OS keyboard animations from racing synthetic enterText events.
    tester.testTextInput.register();
    addTearDown(tester.testTextInput.unregister);
    await serviceLocator.reset();
    final images = await _DeviceImages.start();
    final sessions = AudienceTestSessions(
      audienceSession(user: 'device-fixture-musician', role: 'ROLE_MUSICIAN'),
    );
    final repository = _Announcements();
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
    serviceLocator.registerSingleton<MediaGalleryRepository>(
      _PrivateMedia(images),
    );
    serviceLocator.registerSingleton<ProfileMediaUploadRepository>(_Uploads());
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await serviceLocator.reset();
      sessions.dispose();
      await images.close();
    });
    final checks = <String, bool>{};
    final callbacks = <String>[];
    binding.reportData = {
      'preflight': {'passed': true, 'fixture_base_url': _fixtureBaseUrl},
      'mode': kProfileMode
          ? 'profile'
          : kDebugMode
          ? 'debug'
          : 'release',
      'checks': checks,
      'callbacks': callbacks,
      'limitations': [
        'RAM repository responses: no backend authorization, mutation or capacity measurement.',
        'Real private thumbnail download/decode via same-device loopback; no CDN/TLS/network-quality measurement.',
        'No video playback, audio focus, secure storage, application bootstrap or analytics sender.',
        'Text input is driven by the Flutter test input channel; native keyboard behavior is outside this check.',
      ],
    };

    await _mount(tester, _FeedCard(callbacks));
    await _tapText(tester, 'Duyuruyu aç');
    await _tapText(tester, 'Beğen');
    await _tapText(tester, 'Yorum');
    final hide = find.byTooltip('Bu duyuruyu akışta bir daha gösterme');
    await _reveal(tester, hide, scrollDelta: -240);
    await tester.tap(hide);
    await tester.pumpAndSettle();
    expect(callbacks, ['open', 'like', 'comment', 'HIDE']);
    checks['production_card_actions'] = true;

    await _mount(
      tester,
      AnnouncementDirectoryScreen(repository: repository, sessions: sessions),
    );
    expect(find.text('Akışta gizlenen duyuru'), findsOneWidget);
    expect(repository.directoryRows.single.feedHidden, isTrue);
    expect(
      repository.directoryRows.single.targetProfiles,
      contains('MUSICIAN'),
    );
    expect(find.text('Duyuruyu aç'), findsOneWidget);
    checks['targeted_directory_response_includes_hidden'] = true;

    sessions.replace(
      announcementAdminSession(token: 'in-memory-admin-device-fixture'),
    );
    await _mount(
      tester,
      AnnouncementEditorScreen(repository: repository, sessions: sessions),
    );
    await _tapText(tester, 'Taslağı kaydet');
    expect(repository.creates, 0);
    expect(find.text('Başlık gerekli.'), findsOneWidget);
    expect(find.text('Duyuru metni gerekli.'), findsOneWidget);
    await _enterEditorText(
      tester,
      'Başlık',
      'Telefonda duyuru kontrolü',
      scrollDelta: -240,
    );
    await _enterEditorText(
      tester,
      'Duyuru metni',
      'Bu taslak yalnızca telefon testinin belleğinde tutulur.',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await _setMusicianTarget(tester, false);
    await _tapText(tester, 'Taslağı kaydet');
    expect(repository.creates, 0);
    expect(find.text('En az bir hedef profil seç.'), findsOneWidget);
    await _setMusicianTarget(tester, true, scrollDelta: -240);
    await _tapText(tester, 'Taslağı kaydet');
    expect(repository.creates, 1);
    expect(repository.current.title, 'Telefonda duyuru kontrolü');
    checks['admin_required_fields_and_target_validation'] = true;
    checks['admin_ram_draft_created'] = true;

    // Simulate the server's saved draft projection during attachment processing;
    // do not invoke the operating system picker or upload any user file.
    repository.current = _mediaDraft('PROCESSING');
    await _mount(
      tester,
      AnnouncementEditorScreen(
        id: announcementFixtureId,
        repository: repository,
        sessions: sessions,
      ),
    );
    await _reveal(tester, find.text('Yayınla'));
    final pendingPublish = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Yayınla'),
    );
    expect(pendingPublish.onPressed, isNull);
    expect(
      find.textContaining('Yayınlamak için medya hazır olmalı.'),
      findsOneWidget,
    );
    expect(repository.publishes, 0);
    checks['processing_attachment_cannot_publish'] = true;

    repository.current = _mediaDraft('READY');
    await _mount(
      tester,
      AnnouncementEditorScreen(
        id: announcementFixtureId,
        repository: repository,
        sessions: sessions,
      ),
    );
    final image = find.byType(AppCachedNetworkImage);
    await _reveal(tester, image);
    var decodedPixels = 0;
    for (var attempt = 0; attempt < 40; attempt++) {
      decodedPixels = tester
          .widgetList<RawImage>(find.byType(RawImage))
          .where((value) => value.image != null)
          .fold<int>(
            0,
            (sum, value) => sum + value.image!.width * value.image!.height,
          );
      if (images.requests > 0 && decodedPixels > 0) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(images.requests, greaterThan(0));
    expect(decodedPixels, greaterThan(0));
    expect(
      tester.widget<AppCachedNetworkImage>(image).persistentCache,
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('app_cached_network_image.error')),
      findsNothing,
    );
    expect(repository.publishes, 0);
    checks['private_video_thumbnail_decoded_without_playback'] = true;
    await _tapText(tester, 'Yayınla', scrollDelta: -240);
    expect(find.text('Duyuruyu yayınla'), findsOneWidget);
    await _tapText(tester, 'Onayla');
    expect(repository.publishes, 1);
    expect(repository.current.status, AnnouncementStatus.published);
    checks['ready_attachment_publish_confirmation'] = true;
    expect(tester.takeException(), isNull);
    expect(images.blockedRequests, 0);
    binding.reportData!.addAll({
      'passed': true,
      'draft_creates': repository.creates,
      'publish_requests': repository.publishes,
      'private_image_http_requests': images.requests,
      'private_image_decoded_pixels': decodedPixels,
      'external_requests_blocked': images.blockedRequests,
    });
  });
}

Future<void> _mount(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.navy,
      home: screen,
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> _tapText(
  WidgetTester tester,
  String label, {
  double scrollDelta = 240,
}) async {
  final target = find.text(label);
  await _reveal(tester, target, scrollDelta: scrollDelta);
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason: 'Tap target must be unobscured: $label',
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _reveal(
  WidgetTester tester,
  Finder target, {
  double scrollDelta = 240,
}) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      scrollDelta,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
  }
  expect(target, findsOneWidget);
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> _enterEditorText(
  WidgetTester tester,
  String label,
  String value, {
  double scrollDelta = 240,
}) async {
  final field = find.widgetWithText(TextFormField, label);
  await _reveal(tester, field, scrollDelta: scrollDelta);
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
  expect(
    tester.widget<TextFormField>(field).controller!.text,
    value,
    reason: 'Synthetic text input must reach the field labelled $label',
  );
}

Future<void> _setMusicianTarget(
  WidgetTester tester,
  bool selected, {
  double scrollDelta = 240,
}) async {
  final chip = find.widgetWithText(FilterChip, 'Müzisyen');
  await _reveal(tester, chip, scrollDelta: scrollDelta);
  expect(tester.widget<FilterChip>(chip).selected, !selected);
  expect(chip.hitTestable(), findsOneWidget);
  await tester.tap(chip);
  await tester.pumpAndSettle();
  expect(
    tester.widget<FilterChip>(chip).selected,
    selected,
    reason: 'Target selection must settle before form submission',
  );
}

class _FeedCard extends StatelessWidget {
  const _FeedCard(this.callbacks);
  final List<String> callbacks;
  @override
  Widget build(BuildContext context) => MusicianFeedThemeScope(
    child: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Duyuru cihaz kontrolü')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: MusicianFeedCardRegistry.standard().build(
            context,
            MusicianFeedItem(
              id: 'ANNOUNCEMENT:$announcementFixtureId',
              type: MusicianFeedItemType.announcement,
              payloadVersion: 1,
              occurredAt: DateTime.now().toUtc(),
              position: 2,
              impressionToken: 'fixture-not-a-server-delivery-token',
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
            ),
            MusicianFeedCardActions(
              openItem: (_) => callbacks.add('open'),
              openAuthor: (_, __) {},
              toggleLike: (_) => callbacks.add('like'),
              openComments: (_) => callbacks.add('comment'),
              openLikes: (_) {},
              feedback: (_, action) => callbacks.add(action.apiValue),
              muteAuthor: (_, __) {},
              openCompletionTask: (_) {},
              openPromotion: (_) {},
              toggleCollabSaved: (_, __) {},
              followProfile: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

Announcement _mediaDraft(String status) => Announcement.fromJson({
  ...announcementFixture(status: 'DRAFT'),
  'title': 'Özel video duyurusu',
  'media': {
    'assetId': announcementFixtureAssetId,
    'kind': 'VIDEO',
    'status': status,
    'streamingProtocol': 'PROGRESSIVE',
    'width': 1280,
    'height': 720,
    'durationSeconds': 42,
  },
});

class _Announcements extends AnnouncementTestRepository {
  final directoryRows = [
    Announcement.fromJson({
      ...announcementFixture(hidden: true),
      'title': 'Akışta gizlenen duyuru',
      'targetProfiles': ['MUSICIAN'],
    }),
  ];
  @override
  Future<Result<AnnouncementPage>> announcements({
    String? cursor,
    int limit = 20,
    bool admin = false,
    AnnouncementStatus? status,
  }) async =>
      Result.success(AnnouncementPage(items: directoryRows, hasMore: false));
  @override
  Future<Result<Announcement>> createAnnouncement(
    AnnouncementWrite input,
  ) async {
    creates++;
    current = Announcement.fromJson({
      ...announcementFixture(status: 'DRAFT', version: 0),
      'title': input.title,
      'body': input.body,
      'targetProfiles': input.targetProfiles.toList(),
    });
    return Result.success(current);
  }

  @override
  Future<Result<Announcement>> publishAnnouncement(
    String id, {
    required int expectedVersion,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    publishes++;
    if (id != current.id ||
        expectedVersion != current.version ||
        current.media?.status != 'READY') {
      throw StateError('Unexpected fixture publish transition');
    }
    current = Announcement(
      id: current.id,
      version: current.version + 1,
      title: current.title,
      body: current.body,
      targetProfiles: current.targetProfiles,
      status: AnnouncementStatus.published,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().toUtc(),
      startsAt: DateTime.now().toUtc(),
      firstPublishedAt: DateTime.now().toUtc(),
      media: current.media,
    );
    return Result.success(current);
  }
}

class _Uploads extends Fake implements ProfileMediaUploadRepository {
  @override
  void releaseDraftCleanupLeases(Iterable<String> assetIds) {}
}

class _PrivateMedia extends Fake implements MediaGalleryRepository {
  _PrivateMedia(this.images);
  final _DeviceImages images;
  @override
  Future<Result<MediaAccess>> getAccess(String assetId) async {
    final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));
    return Result.success(
      MediaAccess(
        assetId: assetId,
        accessUrl: images.url('private-video-not-played.mp4'),
        expiresAt: expiry,
        thumbnailAccessUrl: images.url('private-thumbnail.png'),
        thumbnailExpiresAt: expiry,
        streamingProtocol: 'PROGRESSIVE',
      ),
    );
  }
}

class _DeviceImages extends HttpOverrides {
  _DeviceImages(this.server, this.previous);
  final HttpServer server;
  final HttpOverrides? previous;
  final runId = DateTime.now().microsecondsSinceEpoch.toString();
  int requests = 0, blockedRequests = 0;
  static Future<_DeviceImages> start() async {
    final asset = await rootBundle.load(
      'assets/buraya_bakarlar_1500x450_v2.png',
    );
    final Uint8List bytes = asset.buffer.asUint8List(
      asset.offsetInBytes,
      asset.lengthInBytes,
    );
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final result = _DeviceImages(server, HttpOverrides.current);
    server.listen((request) async {
      result.requests++;
      request.response
        ..headers.contentType = ContentType('image', 'png')
        ..headers.set(
          HttpHeaders.cacheControlHeader,
          'private,no-store,max-age=0',
        )
        ..contentLength = bytes.length
        ..add(bytes);
      await request.response.close();
    });
    HttpOverrides.global = result;
    return result;
  }

  String url(String name) => '$_fixtureBaseUrl/$runId/$name';
  Uri route(Uri value) {
    if (value.scheme == 'https' &&
        value.host == 'announcement-device.invalid') {
      return value.replace(
        scheme: 'http',
        host: '127.0.0.1',
        port: server.port,
      );
    }
    if ({'127.0.0.1', 'localhost', '::1'}.contains(value.host)) return value;
    blockedRequests++;
    throw StateError('External network is disabled in announcement device QA.');
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _LoopbackClient(super.createHttpClient(context), route);
  Future<void> close() async {
    await server.close(force: true);
    HttpOverrides.global = previous;
  }
}

class _LoopbackClient extends Fake implements HttpClient {
  _LoopbackClient(this.inner, this.route);
  final HttpClient inner;
  final Uri Function(Uri) route;
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      inner.openUrl(method, route(url));
  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);
  @override
  String? get userAgent => inner.userAgent;
  @override
  set userAgent(String? value) => inner.userAgent = value;
  @override
  bool get autoUncompress => inner.autoUncompress;
  @override
  set autoUncompress(bool value) => inner.autoUncompress = value;
  @override
  void close({bool force = false}) => inner.close(force: force);
}
