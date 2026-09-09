import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/create_band_screen.dart';

void main() {
  late _Bands bands;
  late _Sessions sessions;

  setUp(() async {
    await serviceLocator.reset();
    bands = _Bands();
    sessions = _Sessions();
    serviceLocator.registerSingleton<BandRepository>(bands);
    serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  });
  tearDown(() => serviceLocator.reset());

  test(
    'create, update and delete carry the originating account to transport',
    () async {
      final api = _Api();
      final repository = BandRepositoryImpl(api);
      expect(
        (await repository.createBand(
          name: 'Band',
          expectedSessionKey: ' account ',
        )).isSuccess,
        isTrue,
      );
      expect(api.method, ApiHttpMethod.post);
      expect(api.context?.expectedSessionKey, 'account');
      expect(
        (await repository.updateBand(
          bandId: 'band',
          description: 'Bio',
          expectedSessionKey: 'account',
        )).isSuccess,
        isTrue,
      );
      expect(api.method, ApiHttpMethod.put);
      expect(api.context?.expectedSessionKey, 'account');
      expect(
        (await repository.deleteBand(
          bandId: 'band',
          expectedSessionKey: 'account',
        )).isSuccess,
        isTrue,
      );
      expect(api.method, ApiHttpMethod.delete);
      expect(api.context?.expectedSessionKey, 'account');
      expect(api.calls, 3);
    },
  );

  test(
    'missing mutation account fails closed before any transport call',
    () async {
      final api = _Api();
      final repository = BandRepositoryImpl(api);
      expect(
        (await repository.createBand(
          name: 'Band',
          expectedSessionKey: ' ',
        )).isSuccess,
        isFalse,
      );
      expect(
        (await repository.updateBand(
          bandId: 'band',
          expectedSessionKey: '',
        )).isSuccess,
        isFalse,
      );
      expect(
        (await repository.deleteBand(
          bandId: 'band',
          expectedSessionKey: ' ',
        )).isSuccess,
        isFalse,
      );
      expect(api.calls, 0);
    },
  );

  testWidgets('duplicate submit sends one creation with the entry account', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), '  New Band  ');
    await tester.tap(find.text('Bandı oluştur'));
    await tester.tap(find.text('Bandı oluştur'));
    expect(bands.calls, 1);
    expect(bands.account, 'account');
    expect(bands.name, 'New Band');
    bands.pending.complete(const Result.success(_created));
    await tester.pumpAndSettle();
    expect(find.byType(CreateBandScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'account switch discards late creation and never pops the new route',
    (tester) async {
      final navigator = await _open(tester);
      await tester.enterText(find.byType(TextField), 'Band');
      await tester.tap(find.text('Bandı oluştur'));
      sessions.change(_session('other'));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('other route')),
        ),
      );
      await tester.pumpAndSettle();
      bands.pending.complete(const Result.success(_created));
      await tester.pumpAndSettle();
      expect(find.text('other route'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        find.text('Oturum değişti. Bu sayfayı yeniden aç.'),
        findsOneWidget,
      );
      expect(bands.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'late success does not pop a covering route or permit duplicate creation',
    (tester) async {
      final navigator = await _open(tester);
      await tester.enterText(find.byType(TextField), 'Band');
      await tester.tap(find.text('Bandı oluştur'));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('cover')),
        ),
      );
      await tester.pumpAndSettle();
      bands.pending.complete(const Result.success(_created));
      await tester.pumpAndSettle();
      expect(find.text('cover'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Oluşturuldu'), findsOneWidget);
      expect(
        find.text('Band oluşturuldu. Bandlerim listesini yenile.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Oluşturuldu'));
      expect(bands.calls, 1);
    },
  );

  testWidgets(
    'unexpected creation failure releases submit and gives a retry message',
    (tester) async {
      await _open(tester);
      await tester.enterText(find.byType(TextField), 'Band');
      await tester.tap(find.text('Bandı oluştur'));
      bands.pending.completeError(StateError('connection closed'));
      await tester.pumpAndSettle();
      expect(
        find.text('Band oluşturulamadı. Lütfen tekrar dene.'),
        findsOneWidget,
      );
      expect(find.text('Bandı oluştur'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('oversized name is rejected before creation', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), 'x' * 101);
    await tester.tap(find.text('Bandı oluştur'));
    await tester.pump();
    expect(
      find.text('Band adı en fazla 100 karakter olabilir.'),
      findsOneWidget,
    );
    expect(bands.calls, 0);
  });
}

Future<GlobalKey<NavigatorState>> _open(WidgetTester tester) async {
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<BandSummary>(
                builder: (_) => CreateBandScreen(),
              ),
            ),
            child: const Text('open create'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open create'));
  await tester.pumpAndSettle();
  return navigator;
}

const _created = BandSummary(
  id: 'band',
  name: 'Band',
  description: null,
  profilePictureUrl: null,
);

class _Bands extends Fake implements BandRepository {
  Completer<Result<BandSummary>>? _pending;
  Completer<Result<BandSummary>> get pending =>
      _pending ??= Completer<Result<BandSummary>>();
  int calls = 0;
  String? account;
  String? name;
  @override
  Future<Result<BandSummary>> createBand({
    required String name,
    required String expectedSessionKey,
    String? description,
  }) {
    calls++;
    account = expectedSessionKey;
    this.name = name;
    return pending.future;
  }
}

class _Sessions extends Fake implements AuthSessionManager {
  AuthSession current = _session('account');
  final listeners = <VoidCallback>{};
  @override
  AuthSession get session => current;
  @override
  void addListener(VoidCallback listener) => listeners.add(listener);
  @override
  void removeListener(VoidCallback listener) => listeners.remove(listener);
  void change(AuthSession next) {
    current = next;
    for (final listener in List.of(listeners)) {
      listener();
    }
  }
}

AuthSession _session(String user) => AuthSession.authenticated(
  token: '$user-token',
  userId: user,
  username: user,
  accountStatus: 'ACTIVE',
  roles: ['ROLE_MUSICIAN'],
  permissions: [],
  expiresAt: DateTime.utc(2040),
  isAdmin: false,
);

class _Api extends Fake implements ApiClient {
  int calls = 0;
  ApiHttpMethod? method;
  ApiRequestContext? context;
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object? json)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls++;
    this.method = method;
    context = requestContext;
    return decoder!({'id': 'band', 'name': 'Band', 'members': []});
  }
}
