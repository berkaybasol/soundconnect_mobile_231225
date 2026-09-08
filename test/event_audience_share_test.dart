import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/venue_event_detail.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/venue_event_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_card.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_data.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_flow.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_service.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/event_share_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);

void main() {
  test('unregistered production exporter resolves to the platform service', () {
    expect(resolveAudienceShareService(), isA<PlatformEventShareService>());
    final injected = _Exporter();
    expect(resolveAudienceShareService(injected), same(injected));
  });

  for (final status in EventAudienceStatus.values) {
    testWidgets(
      'personal export $status keeps fixed canvas and performer consent',
      (tester) async {
        if (Platform.environment['EVENT_AUDIENCE_RENDER_DIR'] != null) {
          await tester.runAsync(() async {
            final fonts =
                '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
            final loader = FontLoader('Roboto');
            for (final file in [
              'roboto-regular.ttf',
              'roboto-medium.ttf',
              'roboto-bold.ttf',
              'roboto-black.ttf',
            ]) {
              loader.addFont(
                File('$fonts/$file').readAsBytes().then(ByteData.sublistView),
              );
            }
            await loader.load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
        }
        tester.view.physicalSize = const Size(420, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = EventShareData.fromDetail(
          _event(),
          audienceStatus: status,
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.navy,
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: boundary,
                  child: EventShareCard(data: data),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(EventShareCard)),
          const Size(360, 640),
        );
        expect(
          find.byKey(const Key('event-share-audience-status')),
          status == EventAudienceStatus.none ? findsNothing : findsOneWidget,
        );
        expect(data.performerLabel, 'Sanatçı');
        expect(data.accessibilityDescription, isNot(contains('@Sanatçı')));
        expect(tester.takeException(), isNull);
        final output = Platform.environment['EVENT_AUDIENCE_RENDER_DIR'];
        if (output != null && output.isNotEmpty) {
          await tester.runAsync(() async {
            final pixels =
                await (boundary.currentContext!.findRenderObject()!
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await pixels.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output).create(recursive: true);
            await File(
              '$output/share-${status.name}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            pixels.dispose();
          });
        }
      },
    );
  }

  for (final status in [
    null,
    EventAudienceStatus.going,
    EventAudienceStatus.thinking,
  ]) {
    testWidgets(
      'explicit $status share reuses fresh event and platform exporter',
      (tester) async {
        final h = await _Harness.mount(tester);
        h.audience.status = status ?? EventAudienceStatus.none;
        final future = h.share(status: status);
        await tester.pumpAndSettle();
        expect(h.exporter.prepared.single.audienceStatus, status);
        expect(
          h.exporter.prepared.single.description,
          'Mekanın güncel etkinlik açıklaması',
        );
        await tester.ensureVisible(
          find.byKey(const Key('event-share-target-other')),
        );
        await tester.tap(find.byKey(const Key('event-share-target-other')));
        await tester.pumpAndSettle();
        await future;
        expect(h.exporter.sent, 1);
        expect(h.audience.reads, status == null ? 0 : 2);
      },
    );
  }

  testWidgets(
    'musician may export a personal plan without profile publication',
    (tester) async {
      final h = await _Harness.mount(tester, role: 'ROLE_MUSICIAN');
      final future = h.share(status: EventAudienceStatus.going);
      await tester.pumpAndSettle();
      expect(find.byType(EventShareSheet), findsOneWidget);
      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      await future;
      expect(h.exporter.sent, 0);
    },
  );

  testWidgets('duplicate share taps prepare just one preview', (tester) async {
    final h = await _Harness.mount(tester);
    final first = h.share();
    final second = h.share();
    await tester.pumpAndSettle();
    expect(h.events.reads, 1);
    expect(h.exporter.prepared, hasLength(1));
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    await Future.wait([first, second]);
  });

  testWidgets(
    'account change during event read never renders prior personal plan',
    (tester) async {
      final h = await _Harness.mount(tester);
      final pending = Completer<Result<VenueEventDetail>>();
      h.events.pending = pending.future;
      final future = h.share();
      await tester.pump();
      h.sessions.replace(const AuthSession.guest());
      pending.complete(Result.success(_event()));
      await future;
      await tester.pumpAndSettle();
      expect(h.exporter.prepared, isEmpty);
      expect(find.byType(EventShareSheet), findsNothing);
    },
  );

  testWidgets('account change closes preview and cannot export prepared data', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    h.audience.status = EventAudienceStatus.thinking;
    final future = h.share(status: EventAudienceStatus.thinking);
    await tester.pumpAndSettle();
    expect(find.byType(EventShareSheet), findsOneWidget);
    h.sessions.replace(_session(user: 'other'));
    await tester.pumpAndSettle();
    await future;
    expect(find.byType(EventShareSheet), findsNothing);
    expect(h.exporter.sent, 0);
    expect(h.sessions.hasActiveListeners, isFalse);
  });

  testWidgets(
    'invalid session before the first share-sheet frame removes the route',
    (tester) async {
      final h = await _Harness.mount(tester);
      final captured = h.sessions.session;
      final future = showEventShareSheet(
        h.context,
        PreparedEventShare(
          bytes: _pixel,
          data: EventShareData.fromDetail(_event()),
        ),
        validityChanges: h.sessions,
        isValid: () => identical(h.sessions.session, captured),
      );
      h.sessions.replace(const AuthSession.guest());
      await tester.pumpAndSettle();
      expect(find.byType(EventShareSheet, skipOffstage: false), findsNothing);
      expect(ModalRoute.of(h.context)!.isCurrent, isTrue);
      expect(await future, isNull);
      expect(h.sessions.hasActiveListeners, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  for (final change in ['account', 'intent']) {
    testWidgets(
      '$change switch during platform file preparation cannot export old personal PNG',
      (tester) async {
        final h = await _Harness.mount(tester);
        final directory = await tester.runAsync(
          () => Directory.systemTemp.createTemp('audience_export_fence_'),
        );
        addTearDown(() async => directory!.delete(recursive: true));
        var platformExports = 0;
        h.exporter.bytes = await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
          final picture = recorder.endRecording();
          final image = await picture.toImage(1, 1);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          picture.dispose();
          return data!.buffer.asUint8List();
        });
        final platform = PlatformEventShareService(
          temporaryDirectory: () async {
            if (change == 'account') {
              h.sessions.replace(_session(user: 'other'));
            } else {
              h.audience.status = EventAudienceStatus.thinking;
              h.audience.changes.value++;
            }
            return directory!;
          },
          platform: TargetPlatform.windows,
          shareSender: (_) async {
            platformExports++;
            return ShareResult.unavailable;
          },
        );
        h.exporter.handoff = (context, prepared, target, isValid) async {
          await tester.runAsync(
            () => platform.share(context, prepared, target, isValid: isValid),
          );
        };
        final future = h.share(status: EventAudienceStatus.going);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('event-share-target-other')),
        );
        await tester.tap(find.byKey(const Key('event-share-target-other')));
        await tester.pumpAndSettle();
        await future;
        expect(platformExports, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('invalidated covered preview removes only its own route', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final future = h.share(status: EventAudienceStatus.going);
    await tester.pumpAndSettle();
    final navigator = Navigator.of(h.context);
    final covering = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Another screen')),
    );
    unawaited(navigator.push(covering));
    await tester.pumpAndSettle();
    h.sessions.replace(const AuthSession.guest());
    await tester.pumpAndSettle();
    expect(find.text('Another screen'), findsOneWidget);
    expect(covering.isCurrent, isTrue);
    expect(find.byType(EventShareSheet, skipOffstage: false), findsNothing);
    await future;
    expect(h.exporter.sent, 0);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(ModalRoute.of(h.context)!.isCurrent, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final ended in [false, true]) {
    testWidgets(
      'personal export aborts if intent changes or event ends after preview ended=$ended',
      (tester) async {
        final h = await _Harness.mount(tester);
        final future = h.share(status: EventAudienceStatus.going);
        await tester.pumpAndSettle();
        if (ended) {
          h.audience.ended = true;
        } else {
          h.audience.status = EventAudienceStatus.thinking;
        }
        await tester.ensureVisible(
          find.byKey(const Key('event-share-target-other')),
        );
        await tester.tap(find.byKey(const Key('event-share-target-other')));
        await tester.pumpAndSettle();
        await future;
        expect(h.exporter.sent, 0);
        expect(
          find.text(
            'Etkinlik veya tercihin değişmiş. Yeniden kontrol edebilirsin.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('a mismatched fresh detail cannot be exported', (tester) async {
    final h = await _Harness.mount(tester);
    h.events.pending = Future.value(Result.success(_event(id: 'wrong')));
    await h.share();
    await tester.pumpAndSettle();
    expect(h.exporter.prepared, isEmpty);
    expect(
      find.text('Paylaşım hazırlanamadı. Lütfen tekrar dene.'),
      findsOneWidget,
    );
  });
}

class _Harness {
  _Harness(this.context, this.sessions);
  final BuildContext context;
  final _Sessions sessions;
  final events = _Events();
  final audience = _Audience();
  final exporter = _Exporter();
  static Future<_Harness> mount(
    WidgetTester tester, {
    String role = 'ROLE_LISTENER',
  }) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    return _Harness(host, _Sessions(_session(role: role)));
  }

  Future<void> share({EventAudienceStatus? status}) => shareAudienceEvent(
    context,
    eventId: 'event',
    status: status,
    sessions: sessions,
    expectedSession: sessions.session,
    repository: events,
    audienceRepository: audience,
    shareService: exporter,
  );
}

class _Sessions extends Fake with ChangeNotifier implements AuthSessionManager {
  _Sessions(this._session);
  AuthSession _session;
  @override
  AuthSession get session => _session;
  bool get hasActiveListeners => hasListeners;
  void replace(AuthSession next) {
    _session = next;
    notifyListeners();
  }
}

class _Events extends Fake implements VenueEventRepository {
  int reads = 0;
  Future<Result<VenueEventDetail>>? pending;
  @override
  Future<Result<VenueEventDetail>> getDetail(String id) {
    reads++;
    return pending ?? Future.value(Result.success(_event()));
  }
}

class _Audience extends Fake implements EventAudienceRepository {
  @override
  final ValueNotifier<int> changes = ValueNotifier(0);
  int reads = 0;
  EventAudienceStatus status = EventAudienceStatus.going;
  bool ended = false;
  @override
  Future<Result<EventAudienceState>> getIntent({
    required String eventId,
    required String expectedSessionKey,
  }) async {
    reads++;
    return Result.success(
      EventAudienceState(
        eventId: eventId,
        intent: status,
        publishedOnProfile: false,
        note: null,
        version: 1,
        updatedAt: DateTime.utc(2026),
        eventAvailable: true,
        eventEnded: ended,
        canSetIntent: !ended,
        canPublish: !ended,
        publicationVisible: false,
        event: _event(),
      ),
    );
  }
}

class _Exporter extends Fake implements EventShareService {
  final prepared = <EventShareData>[];
  int sent = 0;
  Uint8List? bytes;
  Future<void> Function(
    BuildContext,
    PreparedEventShare,
    EventShareTarget,
    bool Function()?,
  )?
  handoff;
  @override
  Future<PreparedEventShare> prepare(
    BuildContext context,
    EventShareData data,
  ) async {
    prepared.add(data);
    return PreparedEventShare(bytes: bytes ?? _pixel, data: data);
  }

  @override
  Future<void> share(
    BuildContext context,
    PreparedEventShare prepared,
    EventShareTarget target, {
    bool Function()? isValid,
  }) async {
    sent++;
    await handoff?.call(context, prepared, target, isValid);
  }
}

AuthSession _session({
  String user = 'listener',
  String role = 'ROLE_LISTENER',
}) => AuthSession.authenticated(
  token: 'token-$user',
  userId: user,
  username: user,
  accountStatus: 'ACTIVE',
  roles: [role],
  permissions: const [],
  expiresAt: DateTime.utc(2099),
  isAdmin: false,
);

VenueEventDetail _event({String id = 'event'}) => VenueEventDetail(
  id: id,
  shareUrl: null,
  posterImage: null,
  performerName: 'Sanatçı',
  musicianProfileId: null,
  title: 'Canlı müzik akşamı',
  description: 'Mekanın güncel etkinlik açıklaması',
  eventDate: DateTime(2026, 9, 20),
  startTime: '20:00',
  endTime: '22:00',
  venueId: 'venue',
  venueName: 'SoundConnect Ankara',
  venueDistrict: 'Çankaya',
  venueCity: 'Ankara',
);
