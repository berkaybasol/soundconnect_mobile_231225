import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/band_received_invitation_page_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/band_summary_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_received_invitation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/my_bands_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_invite_decision_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

void main() {
  test(
    'received read is paginated and fenced without caller-controlled user ID',
    () async {
      final api = _Api();
      final result = await BandRepositoryImpl(
        api,
      ).getReceivedInvitations(expectedSessionKey: ' aedrum ');
      expect(result.isSuccess, isTrue);
      expect(result.data!.items.single.bandName, 'Şahbaz');
      expect(api.path, '/api/v1/user/bands/invitations/received');
      expect(api.query, {'page': 0, 'size': 20});
      expect(api.key, 'aedrum');
      expect(() => result.data!.items.clear(), throwsUnsupportedError);
    },
  );
  for (final invalid in [
    (page: -1, size: 20),
    (page: 0, size: 51),
    (page: 2001, size: 50),
  ]) {
    test('invalid bounds $invalid never reach transport', () async {
      final api = _Api();
      final result = await BandRepositoryImpl(api).getReceivedInvitations(
        expectedSessionKey: 'aedrum',
        page: invalid.page,
        size: invalid.size,
      );
      expect(result.isSuccess, isFalse);
      expect(api.path, isNull);
    });
  }
  for (final entry in <String, Object?>{
    'status': 'ACTIVE',
    'bandId': '',
    'bandName': '',
    'profilePicture': 7,
  }.entries) {
    test('invalid row ${entry.key} is rejected', () {
      final json = _wire();
      (json['content'] as List).first[entry.key] = entry.value;
      expect(
        () => BandReceivedInvitationPageModel.decode(
          json,
          expectedPage: 0,
          expectedSize: 20,
        ),
        throwsFormatException,
      );
    });
  }
  for (final entry in <String, Object?>{
    'page': 0.0,
    'size': 20.0,
    'totalElements': -1,
    'last': false,
    'first': false,
    'totalPages': 4,
    'content': [],
  }.entries) {
    test('malformed metadata ${entry.key} is rejected', () {
      final json = _wire()..[entry.key] = entry.value;
      expect(
        () => BandReceivedInvitationPageModel.decode(
          json,
          expectedPage: 0,
          expectedSize: 20,
        ),
        throwsFormatException,
      );
    });
  }
  test('accept and reject carry expected account', () async {
    final api = _Api();
    final repository = BandRepositoryImpl(api);
    expect(
      (await repository.acceptInvite(
        bandId: 'band',
        expectedSessionKey: 'aedrum',
        invitationId: '00000000-0000-0000-0000-000000000001',
      )).isSuccess,
      isTrue,
    );
    expect(api.key, 'aedrum');
    expect(api.method, ApiHttpMethod.post);
    expect(api.path, endsWith('/accept'));
    await repository.rejectInvite(
      bandId: 'band',
      expectedSessionKey: 'aedrum',
      invitationId: '00000000-0000-0000-0000-000000000001',
    );
    expect(api.key, 'aedrum');
    expect(api.path, endsWith('/reject'));
  });

  late _Bands bands;
  late _Sessions sessions;
  setUp(() async {
    await serviceLocator.reset();
    bands = _Bands();
    sessions = _Sessions();
    serviceLocator.registerSingleton<BandRepository>(bands);
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  });
  tearDown(() async {
    await serviceLocator.reset();
  });

  test(
    'summary carries authoritative founder quota metadata without guessing legacy ownership',
    () {
      final wire = <String, dynamic>{'id': 'band', 'name': 'Band'};
      expect(BandSummaryModel.fromJson(wire).countsTowardCreationLimit, isNull);
      expect(
        BandSummaryModel.fromJson(
          wire..['countsTowardCreationLimit'] = false,
        ).countsTowardCreationLimit,
        isFalse,
      );
      expect(
        BandSummaryModel.fromJson(
          wire..['countsTowardCreationLimit'] = true,
        ).countsTowardCreationLimit,
        isTrue,
      );
    },
  );

  for (final founders in [0, 2, 3]) {
    testWidgets(
      '$founders founded groups and six memberships apply only the founder creation limit',
      (tester) async {
        bands.pending = false;
        bands.summaries = List.generate(
          founders + 6,
          (index) => BandSummary(
            id: 'group-$index',
            name: 'Group $index',
            description: null,
            profilePictureUrl: null,
            countsTowardCreationLimit: index < founders,
          ),
        );
        await _mount(tester);
        expect(find.text('${founders + 6} grup'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Grup oluştur'),
          400,
          scrollable: find.byType(Scrollable).first,
        );
        final create = tester.widget<GradientOutlineButton>(
          find.widgetWithText(GradientOutlineButton, 'Grup oluştur'),
        );
        expect(create.onPressed == null, founders == 3);
        await tester.scrollUntilVisible(
          find.text('Kurduğun gruplar: $founders / 3'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Kurduğun gruplar: $founders / 3'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'unknown legacy membership metadata cannot invent remaining creation rights',
    (tester) async {
      bands.pending = false;
      bands.summaries = [
        const BandSummary(
          id: 'legacy',
          name: 'Legacy',
          description: null,
          profilePictureUrl: null,
        ),
      ];
      await _mount(tester);
      final create = tester.widget<GradientOutlineButton>(
        find.widgetWithText(GradientOutlineButton, 'Grup oluştur'),
      );
      expect(create.onPressed, isNull);
      expect(
        find.text('Grup kurma hakkın doğrulanamadı. Listeyi yenile.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'received invitation available without notification; reject refreshes list',
    (tester) async {
      await _mount(tester);
      expect(find.text('Gelen Davetler'), findsOneWidget);
      expect(find.text('Şahbaz'), findsOneWidget);
      expect(bands.calls, [0]);
      await tester.tap(find.text('Şahbaz'));
      await tester.pumpAndSettle();
      expect(find.byType(BandInviteDecisionScreen), findsOneWidget);
      expect(find.text('Şahbaz seni gruba davet etti'), findsOneWidget);
      await tester.tap(find.text('Reddet'));
      await tester.pumpAndSettle();
      expect(bands.responses, 1);
      expect(bands.responseAccount, 'aedrum');
      expect(find.text('Bekleyen grup davetin yok.'), findsOneWidget);
      expect(bands.calls, [0, 0]);
    },
  );
  testWidgets('accept refreshes active groups and removes pending invitation', (
    tester,
  ) async {
    await _mount(tester);
    await tester.tap(find.text('Şahbaz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kabul et'));
    await tester.pumpAndSettle();
    expect(bands.responses, 1);
    expect(bands.active, true);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 grup'), findsOneWidget);
    expect(find.text('Bekleyen grup davetin yok.'), findsOneWidget);
  });
  testWidgets('account loss clears private list and drops in-flight response', (
    tester,
  ) async {
    final pending = Completer<Result<BandReceivedInvitationPage>>();
    bands.onRead = (_) => pending.future;
    await _mount(tester, settle: false);
    sessions.change(const AuthSession.guest());
    await tester.pump();
    pending.complete(Result.success(_page()));
    await tester.pumpAndSettle();
    expect(find.text('Şahbaz'), findsNothing);
    expect(find.text('Müzisyen hesabınla giriş yap.'), findsOneWidget);
  });
  testWidgets('account switch on decision disables mutations', (tester) async {
    await _mount(tester);
    await tester.tap(find.text('Şahbaz'));
    await tester.pumpAndSettle();
    sessions.change(_session('other'));
    await tester.pumpAndSettle();
    expect(find.text('Kabul et'), findsNothing);
    expect(bands.responses, 0);
  });
  testWidgets('invitation read failure has retry and does not hide groups', (
    tester,
  ) async {
    bands.active = true;
    bands.onRead = (_) async =>
        Result.failure(const AppError(code: 'network', message: 'network'));
    await _mount(tester);
    expect(find.text('1 grup'), findsOneWidget);
    expect(find.text('Gelen davetler yüklenemedi.'), findsOneWidget);
    bands.onRead = null;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('Gelen davetler yüklenemedi.'), findsNothing);
  });
  testWidgets(
    'page boundary drift resets once without retaining stale invitations',
    (tester) async {
      bands.onRead = (page) async => Result.success(
        page == 0
            ? _page(count: 20, total: 21)
            : _page(count: 0, total: 20, page: 1),
      );
      await _mount(tester);
      await tester.scrollUntilVisible(
        find.text('Daha fazla göster'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Daha fazla göster'));
      await tester.pumpAndSettle();
      expect(bands.calls, [0, 1, 0]);
    },
  );
  testWidgets(
    'returning from group profile refreshes without blindly deleting it',
    (tester) async {
      bands.active = true;
      bands.pending = false;
      await _mount(tester);
      await tester.tap(find.text('Şahbaz'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Test profile'))).pop(true);
      await tester.pumpAndSettle();
      expect(find.text('Şahbaz'), findsOneWidget);
      expect(find.text('1 grup'), findsOneWidget);
    },
  );
  testWidgets('pending response blocks double submission and back navigation', (
    tester,
  ) async {
    final response = Completer<Result<void>>();
    bands.response = response.future;
    await _mount(tester);
    await tester.tap(find.text('Şahbaz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kabul et'));
    await tester.tap(find.text('Kabul et'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(bands.responses, 1);
    expect(find.byType(BandInviteDecisionScreen), findsOneWidget);
    response.complete(
      Result.failure(const AppError(code: 'network', message: 'Tekrar dene')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);
  });
  testWidgets(
    'late success after account switch cannot navigate as new account',
    (tester) async {
      final response = Completer<Result<void>>();
      bands.response = response.future;
      await _mount(tester);
      await tester.tap(find.text('Şahbaz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kabul et'));
      await tester.pump();
      sessions.change(_session('other'));
      response.complete(const Result.success(null));
      await tester.pumpAndSettle();
      expect(find.text('Test profile'), findsNothing);
      expect(bands.responseAccount, 'aedrum');
    },
  );
  testWidgets('older refresh cannot replace a newer successful page', (
    tester,
  ) async {
    final old = Completer<Result<BandReceivedInvitationPage>>();
    bands.onRead = (_) => bands.calls.length == 1
        ? old.future
        : Future.value(Result.success(_page(count: 0)));
    await _mount(tester, settle: false);
    await tester.tap(find.byTooltip('Yenile'));
    await tester.pump();
    old.complete(Result.success(_page()));
    await tester.pumpAndSettle();
    expect(find.text('Şahbaz'), findsNothing);
    expect(find.text('Bekleyen grup davetin yok.'), findsOneWidget);
  });
  testWidgets('guest cannot request invitations', (tester) async {
    sessions.value = const AuthSession.guest();
    await _mount(tester);
    expect(bands.calls, isEmpty);
    expect(find.text('Gelen Davetler'), findsNothing);
  });

  for (final theme in ['navy', 'light', 'black']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('groups/invitations fit320dp $theme $scale', (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        bands.longName = true;
        if (const bool.fromEnvironment('BAND_RECEIVED_PREVIEW')) {
          await tester.runAsync(() async {
            const root = String.fromEnvironment('PREVIEW_FLUTTER_ROOT');
            for (final font in {
              'Roboto':
                  '$root/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
              'MaterialIcons':
                  '$root/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
            }.entries) {
              await (FontLoader(font.key)..addFont(
                    File(font.value).readAsBytes().then(ByteData.sublistView),
                  ))
                  .load();
            }
          });
        }
        await _mount(tester, theme: theme, scale: scale);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text('Grup daveti · Yanıtını bekliyor'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!const bool.fromEnvironment('BAND_RECEIVED_PREVIEW')) return;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/band-received-$theme-$scale.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      });
    }
  }
}

Map<String, dynamic> _wire() => {
  'content': [
    <String, dynamic>{
      'bandId': 'band',
      'bandName': 'Şahbaz',
      'profilePicture': null,
      'status': 'PENDING',
    },
  ],
  'page': 0,
  'number': 0,
  'size': 20,
  'totalElements': 1,
  'totalPages': 1,
  'first': true,
  'last': true,
};
BandReceivedInvitationPage _page({
  int count = 1,
  int? total,
  int page = 0,
  bool longName = false,
}) => BandReceivedInvitationPage(
  items: List.generate(
    count,
    (index) => BandReceivedInvitation(
      bandId: 'band-$index',
      invitationId: '00000000-0000-0000-0000-000000000001',
      bandName: longName
          ? 'Dolu Kadehi Ters Tut ve Uzun Grup Adı'
          : count == 1
          ? 'Şahbaz'
          : 'Grup $index',
    ),
  ),
  page: page,
  size: 20,
  totalElements: total ?? count,
  hasNext: (page + 1) * 20 < (total ?? count),
);
AuthSession _session([String user = 'aedrum']) => AuthSession.authenticated(
  token: 'token-$user',
  userId: user,
  username: user,
  accountStatus: 'ACTIVE',
  roles: const ['ROLE_MUSICIAN'],
  permissions: const [],
  expiresAt: DateTime.utc(2040),
  isAdmin: false,
);

class _Sessions extends Fake implements AuthSessionManager {
  AuthSession value = _session();
  final listeners = <VoidCallback>{};
  @override
  AuthSession get session => value;
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  void change(AuthSession next) {
    value = next;
    for (final callback in List.of(listeners)) {
      callback();
    }
  }
}

class _Bands extends Fake implements BandRepository {
  List<BandSummary>? summaries;
  bool active = false, pending = true, longName = false;
  int responses = 0;
  String? responseAccount;
  Future<Result<void>>? response;
  final calls = <int>[];
  Future<Result<BandReceivedInvitationPage>> Function(int)? onRead;
  @override
  Future<Result<BandReceivedInvitation>> getCurrentReceivedInvitation({
    required String bandId,
    required String expectedSessionKey,
  }) async => pending
      ? Result.success(_page(longName: longName).items.single)
      : const Result.failure(
          AppError(code: '9206', message: 'Geçerli davet bulunamadı.'),
        );
  @override
  Future<Result<List<BandSummary>>> getMyBands() async => Result.success(
    summaries ??
        (active
            ? [
                const BandSummary(
                  id: 'band-0',
                  name: 'Şahbaz',
                  description: null,
                  profilePictureUrl: null,
                  countsTowardCreationLimit: false,
                ),
              ]
            : []),
  );
  @override
  Future<Result<BandReceivedInvitationPage>> getReceivedInvitations({
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  }) async {
    calls.add(page);
    return onRead == null
        ? Result.success(_page(count: pending ? 1 : 0, longName: longName))
        : onRead!(page);
  }

  @override
  Future<Result<BandProfile>> getPublicBandById(String id) async =>
      Result.success(
        BandProfile(
          id: id,
          name: 'Şahbaz',
          description: null,
          profilePictureUrl: null,
          instagramUrl: null,
          youtubeUrl: null,
          soundCloudUrl: null,
          spotifyEmbedUrl: null,
          spotifyArtistId: null,
          spotifyTrackIds: const [],
          members: const [],
        ),
      );
  @override
  Future<Result<void>> acceptInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  }) async {
    responses++;
    responseAccount = expectedSessionKey;
    if (response != null) return response!;
    active = true;
    pending = false;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> rejectInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  }) async {
    responses++;
    responseAccount = expectedSessionKey;
    pending = false;
    return const Result.success(null);
  }
}

class _Api extends ApiClient {
  String? path, key;
  Map<String, dynamic>? query;
  ApiHttpMethod? method;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    this.path = path;
    this.query = query;
    this.method = method;
    key = requestContext?.expectedSessionKey;
    return decoder!(_wire());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _mount(
  WidgetTester tester, {
  bool settle = true,
  String theme = 'navy',
  double scale = 1,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('preview'),
      child: MaterialApp(
        theme: switch (theme) {
          'light' => AppTheme.light,
          'black' => AppTheme.black,
          _ => AppTheme.navy,
        },
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) =>
              Scaffold(appBar: AppBar(), body: const Text('Test profile')),
        ),
        home: const MyBandsScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}
