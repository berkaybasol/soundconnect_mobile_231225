import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_state.dart';
import 'package:soundconnect_23_12_25codx/modules/event_audience/domain/event_audience_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/overthinking_profile_draft.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_profile_share_button.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/listener_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/cubit/listener_profile_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_draft_composer.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/profile_public_bottom_bar.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';

const _sourceId = '0d87cfdc-44ea-48dd-a16c-28e27e92ba4d';
const _preview = bool.fromEnvironment('OVERTHINKING_DRAFT_PREVIEW');
final _source = OverthinkingPostModel.fromJson({
  'id': _sourceId,
  'title': 'Bir şarkının içinde',
  'content': 'Bazen aynı hissi bambaşka hayatlarda taşıyoruz.',
  'anonymous': true,
  'canViewAuthor': false,
  'visibilityType': 'ANONYMOUS',
  'authorUsername': 'Anonymous',
});
final _note = find.byKey(const Key('listener-overthinking-draft-note'));
final _leaveDialog = find.byKey(
  const Key('listener-overthinking-draft-leave-dialog'),
);

void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());

  testWidgets('share button opens own profile draft without a sheet or write', (
    tester,
  ) async {
    final expected = audienceSession();
    final h = await _mountNavigation(tester, expected);
    await tester.tap(find.text('Paylaş'));
    await tester.pumpAndSettle();
    expect(find.text('Own profile'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    final route = h.routes.single;
    expect(route.name, AppRoutes.listenerProfile);
    final args = route.arguments! as OverthinkingProfileDraftArgs;
    expect(args.postId, _sourceId);
    expect(args.expectedSession, same(expected));
    expect(h.shares.reads, isEmpty);
    expect(h.shares.writes, isEmpty);
    expect(h.shares.deleted, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'draft navigation trims ids, fences rapid taps and reopens on return',
    (tester) async {
      final h = await _mountNavigation(tester, audienceSession());
      unawaited(h.open(postId: '  $_sourceId  '));
      unawaited(h.open());
      await tester.pumpAndSettle();
      expect(h.routes, hasLength(1));
      expect(
        (h.routes.single.arguments! as OverthinkingProfileDraftArgs).postId,
        _sourceId,
      );
      h.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      unawaited(h.open());
      await tester.pumpAndSettle();
      expect(h.routes, hasLength(2));
      expect(h.shares.writes, isEmpty);
    },
  );

  for (final entry in <String, AuthSession>{
    'guest': const AuthSession.guest(),
    'musician on Mainstage': audienceSession(role: 'ROLE_MUSICIAN'),
    'venue': audienceSession(role: 'ROLE_VENUE'),
    'studio': audienceSession(role: 'ROLE_STUDIO'),
    'organizer': audienceSession(role: 'ROLE_ORGANIZER'),
    'producer': audienceSession(role: 'ROLE_PRODUCER'),
    'inactive listener': audienceSession(status: 'INACTIVE'),
    'onboarding listener': AuthSession.authenticated(
      token: 'token',
      userId: 'listener',
      username: 'listener',
      accountStatus: 'ACTIVE',
      roles: const ['ROLE_LISTENER'],
      permissions: const [],
      expiresAt: DateTime.utc(2100),
      isAdmin: false,
      requiresListenerProfileChoice: true,
    ),
    'admin listener': audienceSession(isAdmin: true),
    'owner listener': audienceSession(roles: ['ROLE_LISTENER', 'ROLE_OWNER']),
    'mixed personal roles': audienceSession(
      roles: ['ROLE_LISTENER', 'ROLE_MUSICIAN'],
    ),
    'mixed studio listener': audienceSession(
      roles: ['ROLE_LISTENER', 'ROLE_STUDIO'],
    ),
  }.entries) {
    testWidgets('${entry.key} has neither share CTA nor draft access', (
      tester,
    ) async {
      final h = await _mountNavigation(tester, entry.value);
      expect(find.text('Paylaş'), findsNothing);
      await h.open();
      await tester.pumpAndSettle();
      expect(h.routes, isEmpty);
      expect(h.shares.reads, isEmpty);
      expect(h.shares.writes, isEmpty);
    });
  }

  testWidgets(
    'retained callback cannot navigate for another account or token',
    (tester) async {
      final h = await _mountNavigation(tester, audienceSession());
      for (final next in [
        audienceSession(user: 'other-listener'),
        audienceSession(token: 'rotated-token'),
        const AuthSession.guest(),
      ]) {
        h.sessions.replace(next);
        await h.open();
        await tester.pumpAndSettle();
        expect(h.routes, isEmpty);
      }
      expect(h.shares.reads, isEmpty);
      expect(h.shares.writes, isEmpty);
    },
  );

  testWidgets('blank ids and covered or disposed contexts cannot open drafts', (
    tester,
  ) async {
    final h = await _mountNavigation(tester, audienceSession());
    await h.open(postId: '   ');
    expect(h.routes, isEmpty);
    unawaited(h.navigator.currentState!.pushNamed('/newer'));
    await tester.pumpAndSettle();
    await h.open();
    expect(h.routes.single.name, '/newer');
    await tester.pumpWidget(const SizedBox.shrink());
    await h.open();
    expect(h.routes, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real own profile loads inline draft and publishes only explicitly',
    (tester) async {
      final h = await _mountProfile(tester);
      expect(_note, findsOneWidget);
      expect(tester.getRect(_note).top, lessThan(760));
      expect(h.sources.reads, [_sourceId]);
      expect(h.shares.reads.single, same(h.sessions.session));
      expect(h.shares.writes, isEmpty);
      expect(h.events.writes, isEmpty);
      await tester.enterText(_note, '  Bu satırlar tam bugünüm.  ');
      expect(h.shares.writes, isEmpty);
      await _tap(
        tester,
        find.byKey(const Key('listener-overthinking-draft-publish')),
      );
      expect(h.shares.writes.single.note, 'Bu satırlar tam bugünüm.');
      expect(h.shares.writes.single.session, same(h.sessions.session));
      expect(h.shares.writes.single.postId, _sourceId);
      expect(find.byType(ListenerOverthinkingDraftComposer), findsNothing);
      expect(h.shares.deleted, isEmpty);
      expect(h.events.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final replacement in ['another account', 'another token']) {
    testWidgets('direct profile draft rejects $replacement session boundary', (
      tester,
    ) async {
      final expected = audienceSession();
      final current = replacement == 'another account'
          ? audienceSession(user: 'other-listener')
          : audienceSession(token: 'other-token');
      final h = await _mountProfile(
        tester,
        sessions: AudienceTestSessions(current),
        expected: expected,
      );
      expect(_note, findsNothing);
      expect(h.sources.reads, isEmpty);
      expect(h.shares.reads, isEmpty);
      expect(h.shares.writes, isEmpty);
    });
  }

  testWidgets(
    'account change before profile load completes never mounts the retained draft',
    (tester) async {
      final reply = Completer<Result<ListenerProfile>>();
      final h = await _mountProfile(
        tester,
        profiles: _Profiles()..onRead = () => reply.future,
        pushed: true,
        settle: false,
      );
      h.sessions.replace(audienceSession(token: 'replacement-token'));
      await tester.pump();
      reply.complete(Result.success(_profile()));
      await tester.pump();
      expect(_note, findsNothing);
      expect(h.sources.reads, isEmpty);
      expect(h.shares.reads, isEmpty);
      expect(h.shares.writes, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('OPEN PROFILE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final target in ['back', 'bottom navigation', 'settings menu']) {
    testWidgets('real profile dirty draft guards $target and retains note', (
      tester,
    ) async {
      final h = await _mountProfile(tester);
      await tester.enterText(_note, 'Kaybolmasın');
      FocusManager.instance.primaryFocus?.unfocus();
      if (target == 'back') {
        await tester.binding.handlePopRoute();
      } else if (target == 'bottom navigation') {
        unawaited(Future.sync(_beforeNavigate(tester)));
      } else {
        await tester.tap(find.byKey(const Key('listener-owner-menu')));
      }
      await tester.pumpAndSettle();
      expect(_leaveDialog, findsOneWidget);
      await _tap(tester, find.text('Düzenlemeye devam et'));
      expect(_noteText(tester), 'Kaybolmasın');
      expect(h.shares.writes, isEmpty);
      expect(h.shares.deleted, isEmpty);
    });
  }

  testWidgets('offscreen inline draft retains its note and navigation guard', (
    tester,
  ) async {
    final h = await _mountProfile(tester);
    await tester.enterText(_note, 'Sayfa kayınca kaybolma');
    FocusManager.instance.primaryFocus?.unfocus();
    final list = tester.widget<ListView>(
      find.byKey(const Key('listener-owner-profile-content')),
    );
    list.controller!.jumpTo(0);
    await tester.pumpAndSettle();
    unawaited(Future.sync(_beforeNavigate(tester)));
    await tester.pumpAndSettle();
    expect(_leaveDialog, findsOneWidget);
    await _tap(tester, find.text('Düzenlemeye devam et'));
    list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(_noteText(tester), 'Sayfa kayınca kaybolma');
    expect(h.shares.reads, hasLength(1));
    expect(h.shares.writes, isEmpty);
  });

  testWidgets(
    'pending inline publication blocks profile navigation until completion',
    (tester) async {
      final reply = Completer<Result<OverthinkingProfileShareState>>();
      final shares = _Shares()..onPublish = () => reply.future;
      final h = await _mountProfile(tester, shares: shares);
      tester
          .widget<GradientOutlineButton>(
            find.byKey(const Key('listener-overthinking-draft-publish')),
          )
          .onPressed!();
      await tester.pump();
      expect(await _beforeNavigate(tester)(), isFalse);
      expect(h.shares.writes, hasLength(1));
      reply.complete(Result.success(_shareState(published: true)));
      await tester.pumpAndSettle();
      expect(find.byType(ListenerOverthinkingDraftComposer), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed initial profile load never traps back in an unmounted draft',
    (tester) async {
      final profiles = _Profiles()
        ..onRead = () async => const Result.failure(
          AppError(code: 'network', message: 'Profile unavailable'),
        );
      final h = await _mountProfile(tester, profiles: profiles, pushed: true);
      expect(_note, findsNothing);
      expect(h.sources.reads, isEmpty);
      expect(h.shares.reads, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('OPEN PROFILE'), findsOneWidget);
      expect(find.byType(ListenerProfileScreen), findsNothing);
      expect(h.shares.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'back can leave pending initial profile load and late reply cannot open a draft',
    (tester) async {
      final reply = Completer<Result<ListenerProfile>>();
      final profiles = _Profiles()..onRead = () => reply.future;
      final h = await _mountProfile(
        tester,
        profiles: profiles,
        pushed: true,
        settle: false,
      );
      expect(_note, findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('OPEN PROFILE'), findsOneWidget);
      reply.complete(Result.success(_profile()));
      await tester.pumpAndSettle();
      expect(find.byType(ListenerProfileScreen), findsNothing);
      expect(h.sources.reads, isEmpty);
      expect(h.shares.reads, isEmpty);
      expect(h.shares.writes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final layout in [(390.0, 1.0), (320.0, 1.6)]) {
    testWidgets('inline profile draft viewport ${layout.$1}/${layout.$2}', (
      tester,
    ) async {
      if (_preview) await _loadPreviewFonts(tester);
      final capture = GlobalKey();
      final h = await _mountProfile(
        tester,
        width: layout.$1,
        scale: layout.$2,
        capture: capture,
      );
      expect(_note, findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(h.shares.writes, isEmpty);
      await tester.enterText(
        _note,
        'Bu hissi başka bir hayatın içinde bulmak.',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final publish = find.byKey(
        const Key('listener-overthinking-draft-publish'),
      );
      for (final target in [_note, publish]) {
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        final rect = tester.getRect(target);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(layout.$1));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(844));
      }
      expect(h.shares.writes, isEmpty);
      expect(tester.takeException(), isNull);
      if (_preview) {
        if (layout.$1 == 320) {
          await _captureProfile(tester, capture, 320, suffix: '-footer');
          await tester.ensureVisible(
            find.byKey(
              const ValueKey('listener-overthinking-draft-$_sourceId'),
            ),
          );
          await tester.pumpAndSettle();
        }
        await _captureProfile(tester, capture, layout.$1.toInt());
      }
    });
  }

  testWidgets(
    'profile ghost refresh clears draft and immediately releases system back',
    (tester) async {
      final h = await _mountProfile(tester, pushed: true);
      await tester.enterText(_note, 'Gizli taslak');
      h.profiles.current = _profile(ghost: true);
      await h.cubit.loadMyProfile();
      await tester.pumpAndSettle();
      expect(_note, findsNothing);
      expect(h.shares.writes, isEmpty);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('OPEN PROFILE'), findsOneWidget);
      expect(find.byType(ListenerProfileScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<bool> Function() _beforeNavigate(WidgetTester tester) =>
    () async => await tester
        .widget<ProfilePublicBottomBar>(find.byType(ProfilePublicBottomBar))
        .onBeforeNavigate!();
String _noteText(WidgetTester tester) =>
    tester.widget<TextField>(_note).controller!.text;
Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<_NavigationHarness> _mountNavigation(
  WidgetTester tester,
  AuthSession session,
) async {
  final h = _NavigationHarness(session);
  addTearDown(h.sessions.dispose);
  addTearDown(h.shares.signal.dispose);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: h.navigator,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            h.context = context;
            return OverthinkingProfileShareButton(
              post: _source,
              sessions: h.sessions,
              repository: h.shares,
            );
          },
        ),
      ),
      onGenerateRoute: (settings) {
        h.routes.add(settings);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(
            body: Text(
              settings.name == AppRoutes.listenerProfile
                  ? 'Own profile'
                  : 'Newer route',
            ),
          ),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

class _NavigationHarness {
  _NavigationHarness(this.expected) : sessions = AudienceTestSessions(expected);
  final AuthSession expected;
  final AudienceTestSessions sessions;
  final shares = _Shares();
  final navigator = GlobalKey<NavigatorState>();
  final routes = <RouteSettings>[];
  late BuildContext context;
  Future<void> open({String postId = _sourceId}) =>
      openOverthinkingProfileDraft(
        context,
        postId: postId,
        expectedSession: expected,
        sessions: sessions,
      );
}

Future<_ProfileHarness> _mountProfile(
  WidgetTester tester, {
  AudienceTestSessions? sessions,
  AuthSession? expected,
  _Shares? shares,
  _Profiles? profiles,
  bool pushed = false,
  bool settle = true,
  double width = 390,
  double scale = 1,
  GlobalKey? capture,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final h = _ProfileHarness(
    sessions ?? AudienceTestSessions(audienceSession()),
    shares ?? _Shares(),
    profiles: profiles,
  );
  addTearDown(h.sessions.dispose);
  addTearDown(h.shares.signal.dispose);
  addTearDown(h.events.signal.dispose);
  serviceLocator
    ..registerSingleton<AuthSessionManager>(h.sessions)
    ..registerSingleton<OverthinkingProfileShareRepository>(h.shares)
    ..registerSingleton<OverthinkingRepository>(h.sources)
    ..registerSingleton<EventAudienceRepository>(h.events)
    ..registerSingleton<DmBadgeCubit>(_Badges());
  final screen = ListenerProfileScreen(
    cubitFactory: () => h.cubit,
    overthinkingDraft: OverthinkingProfileDraftArgs(
      postId: _sourceId,
      expectedSession: expected ?? h.sessions.session,
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _preview
          ? AppTheme.navy.copyWith(
              textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
              primaryTextTheme: AppTheme.navy.primaryTextTheme.apply(
                fontFamily: 'Roboto',
              ),
            )
          : AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: RepaintBoundary(key: capture, child: child!),
      ),
      home: pushed
          ? Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push<void>(MaterialPageRoute(builder: (_) => screen)),
                  child: const Text('OPEN PROFILE'),
                ),
              ),
            )
          : screen,
    ),
  );
  if (pushed) await tester.tap(find.text('OPEN PROFILE'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
  return h;
}

Future<void> _loadPreviewFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final directory =
        '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
    final loader = FontLoader('Roboto');
    for (final file in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
      'roboto-black.ttf',
    ]) {
      loader.addFont(
        File('$directory/$file').readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
}

Future<void> _captureProfile(
  WidgetTester tester,
  GlobalKey capture,
  int width, {
  String suffix = '',
}) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(ListenerProfileScreen));
    for (final asset in [
      'assets/logo.png',
      'assets/Logoyanyana.png',
      'assets/ME!2-transparent.png',
      'assets/confined.png',
    ]) {
      await precacheImage(AssetImage(asset), context);
    }
    for (final rendered in tester.widgetList<Image>(find.byType(Image))) {
      if (context.mounted) await precacheImage(rendered.image, context);
    }
  });
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.runAsync(() async {
    final pixels =
        await (capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await pixels.toByteData(format: ui.ImageByteFormat.png);
    final output = Directory('test/goldens/overthinking');
    await output.create(recursive: true);
    await File(
      '${output.path}/inline-draft$width$suffix.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    pixels.dispose();
  });
}

class _ProfileHarness {
  _ProfileHarness(this.sessions, this.shares, {_Profiles? profiles})
    : profiles = profiles ?? _Profiles();
  final AudienceTestSessions sessions;
  final _Shares shares;
  final sources = _Sources();
  final _Profiles profiles;
  final events = _Events();
  late final cubit = ListenerProfileCubit(profiles, sessions: sessions);
}

OverthinkingProfileShareState _shareState({
  bool published = false,
  String? note,
}) => OverthinkingProfileShareState(
  postId: _sourceId,
  shareId: published ? 'exact-share' : null,
  publishedOnProfile: published,
  note: note,
  publishedAt: published ? DateTime.utc(2026, 9, 10) : null,
  canPublish: true,
);

class _Shares extends Fake implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  final reads = <AuthSession>[];
  final writes = <({String postId, String? note, AuthSession session})>[];
  final deleted = <String>[];
  var current = _shareState();
  Future<Result<OverthinkingProfileShareState>> Function()? onPublish;
  @override
  Future<Result<OverthinkingProfileShareState>> getState({
    required String postId,
    required AuthSession expectedSession,
  }) async {
    reads.add(expectedSession);
    return Result.success(current);
  }

  @override
  Future<Result<OverthinkingProfileShareState>> publish({
    required String postId,
    String? note,
    required AuthSession expectedSession,
  }) async {
    writes.add((postId: postId, note: note, session: expectedSession));
    if (onPublish != null) return onPublish!();
    current = _shareState(published: true, note: note);
    signal.value++;
    return Result.success(current);
  }

  @override
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  }) async {
    deleted.add(shareId);
    return const Result.success(null);
  }

  @override
  Future<Result<Page<OverthinkingProfileShare>>> listProfile({
    required String profileId,
    required AuthSession expectedSession,
    int page = 0,
    int size = 20,
  }) async =>
      const Result.success(Page(items: [], hasNext: false, totalElements: 0));
}

class _Sources extends Fake implements OverthinkingRepository {
  final reads = <String>[];
  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async {
    reads.add(postId);
    return Result.success(_source);
  }
}

ListenerProfile _profile({bool ghost = false}) => ListenerProfile(
  id: 'profile',
  userId: 'listener',
  username: 'deniz',
  bio: 'Müziğin peşinde.',
  profilePictureUrl: null,
  followerCount: 12,
  followingCount: 8,
  visibilityChoiceCompleted: true,
  visibilityMode: ghost
      ? ListenerVisibilityMode.ghost
      : ListenerVisibilityMode.standard,
);

class _Profiles extends ListenerProfileRepository {
  ListenerProfile current = _profile();
  Future<Result<ListenerProfile>> Function()? onRead;
  @override
  Future<Result<ListenerProfile>> getMyProfile() async =>
      onRead?.call() ?? Result.success(current);
}

class _Events extends AudienceTestRepository {
  @override
  Future<Result<EventAudiencePage<EventAudiencePost>>> listPublic(
    String listenerProfileId, {
    String? expectedSessionKey,
    EventAudiencePeriod period = EventAudiencePeriod.all,
    int page = 0,
    int size = 20,
  }) async => Result.success(
    EventAudiencePage(
      items: const [],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 0,
      hasNext: false,
    ),
  );
}

class _Badges extends Cubit<DmBadgeState> implements DmBadgeCubit {
  _Badges() : super(const DmBadgeState.initial());
  @override
  Future<void> ensureStarted() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
