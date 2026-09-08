import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session_manager.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_client.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/models/band_received_invitation_page_model.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_received_invitation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_invite_decision_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

const _oldId = '00000000-0000-0000-0000-000000000001';
const _newId = '00000000-0000-0000-0000-000000000002';

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
    'current invitation lookup validates target and carries the original account',
    () async {
      final api = _Api()..response = _wire();
      final result = await BandRepositoryImpl(api).getCurrentReceivedInvitation(
        bandId: 'band',
        expectedSessionKey: 'account',
      );
      expect(result.data?.invitationId, _newId);
      expect(api.path, '/api/v1/user/bands/band/invitations/received/current');
      expect(api.context?.expectedSessionKey, 'account');
      api.response = _wire()..['bandId'] = 'other';
      expect(
        (await BandRepositoryImpl(api).getCurrentReceivedInvitation(
          bandId: 'band',
          expectedSessionKey: 'account',
        )).isSuccess,
        isFalse,
      );
    },
  );

  for (final id in [null, '', 'not-a-uuid']) {
    test(
      'missing or invalid immutable invite identity $id never dispatches a decision',
      () async {
        final api = _Api();
        final repository = BandRepositoryImpl(api);
        expect(
          (await repository.acceptInvite(
            bandId: 'band',
            expectedSessionKey: 'account',
            invitationId: id,
          )).isSuccess,
          isFalse,
        );
        expect(
          (await repository.rejectInvite(
            bandId: 'band',
            expectedSessionKey: 'account',
            invitationId: id,
          )).isSuccess,
          isFalse,
        );
        expect(api.calls, 0);
      },
    );
  }

  test(
    'both decisions carry immutable identity in query and account in request context',
    () async {
      final api = _Api();
      final repository = BandRepositoryImpl(api);
      await repository.acceptInvite(
        bandId: 'band',
        expectedSessionKey: 'account',
        invitationId: _oldId,
      );
      expect(api.query, {'invitationId': _oldId});
      expect(api.context?.expectedSessionKey, 'account');
      await repository.rejectInvite(
        bandId: 'band',
        expectedSessionKey: 'account',
        invitationId: _newId,
      );
      expect(api.query, {'invitationId': _newId});
      expect(api.context?.expectedSessionKey, 'account');
    },
  );

  test(
    'legacy received DTO remains readable but cannot acquire an invented identity',
    () {
      final wire = _wire()..remove('invitationId');
      expect(
        BandReceivedInvitationPageModel.decodeInvitation(wire).invitationId,
        isNull,
      );
      wire['invitationId'] = 'wrong';
      expect(
        () => BandReceivedInvitationPageModel.decodeInvitation(wire),
        throwsFormatException,
      );
    },
  );

  Future<void> open(WidgetTester tester, String? invitationId) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.navy,
        home: BandInviteDecisionScreen(
          args: BandInviteDecisionScreenArgs(
            bandId: 'band',
            invitationId: invitationId,
          ),
        ),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Destination')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final id in [null, _oldId]) {
    testWidgets(
      'legacy or superseded $id only opens the latest invitation after an explicit action',
      (tester) async {
        await open(tester, id);
        expect(
          find.textContaining('Bu davet artık geçerli değil.'),
          findsOneWidget,
        );
        expect(find.text('Kabul et'), findsNothing);
        expect(find.text('Reddet'), findsNothing);
        expect(bands.decisions, isEmpty);
        await tester.tap(find.text('Güncel daveti aç'));
        await tester.pumpAndSettle();
        expect(find.text('Kabul et'), findsOneWidget);
        expect(bands.decisions, isEmpty);
        await tester.tap(find.text('Kabul et'));
        await tester.pumpAndSettle();
        expect(bands.decisions, [('accept', _newId, 'account')]);
      },
    );
  }

  testWidgets(
    'reinvite after opening is rejected with the old id and offers current invitation',
    (tester) async {
      bands.currentId = _oldId;
      await open(tester, _oldId);
      bands.currentId = _newId;
      await tester.tap(find.text('Reddet'));
      await tester.pumpAndSettle();
      expect(bands.decisions, [('reject', _oldId, 'account')]);
      expect(find.text('Güncel daveti aç'), findsOneWidget);
      expect(find.text('Reddet'), findsNothing);
    },
  );

  testWidgets(
    'account switch during current invitation read cannot enable decisions',
    (tester) async {
      bands.pendingRead = Completer<Result<BandReceivedInvitation>>();
      await tester.pumpWidget(
        MaterialApp(
          home: BandInviteDecisionScreen(
            args: const BandInviteDecisionScreenArgs(
              bandId: 'band',
              invitationId: _newId,
            ),
          ),
        ),
      );
      await tester.pump();
      sessions.change(const AuthSession.guest());
      bands.pendingRead!.complete(Result.success(_invitation(_newId)));
      await tester.pumpAndSettle();
      expect(
        find.text('Davetini görmek için sayfayı hesabından yeniden aç.'),
        findsOneWidget,
      );
      expect(find.text('Kabul et'), findsNothing);
      expect(bands.decisions, isEmpty);
    },
  );

  testWidgets(
    'preview exception reports a recoverable error without blocking a verified invite',
    (tester) async {
      bands.throwPreview = true;
      await open(tester, _newId);
      expect(find.text('Grup bilgileri yüklenemedi.'), findsOneWidget);
      expect(find.text('Kabul et'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'decision exception releases submission and rechecks the current invitation',
    (tester) async {
      bands.throwDecision = true;
      await open(tester, _newId);
      await tester.tap(find.text('Kabul et'));
      await tester.pumpAndSettle();
      expect(find.text('Grup daveti kabul edilemedi.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      bands.throwDecision = false;
      await tester.tap(find.text('Kabul et'));
      await tester.pumpAndSettle();
      expect(bands.decisions, hasLength(2));
      expect(find.text('Destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Map<String, dynamic> _wire() => {
  'bandId': 'band',
  'bandName': 'Sahbaz',
  'profilePicture': null,
  'status': 'PENDING',
  'invitationId': _newId,
};

BandReceivedInvitation _invitation(String id) => BandReceivedInvitation(
  bandId: 'band',
  bandName: 'Sahbaz',
  invitationId: id,
);

class _Bands extends Fake implements BandRepository {
  String currentId = _newId;
  bool throwPreview = false;
  bool throwDecision = false;
  Completer<Result<BandReceivedInvitation>>? pendingRead;
  final decisions = <(String, String?, String?)>[];
  @override
  Future<Result<BandReceivedInvitation>> getCurrentReceivedInvitation({
    required String bandId,
    required String expectedSessionKey,
  }) async => pendingRead?.future ?? Result.success(_invitation(currentId));
  @override
  Future<Result<BandProfile>> getPublicBandById(String bandId) async {
    if (throwPreview) throw StateError('Offline');
    return Result.success(
      BandProfile(
        id: bandId,
        name: 'Sahbaz',
        description: null,
        profilePictureUrl: null,
        instagramUrl: null,
        youtubeUrl: null,
        soundCloudUrl: null,
        spotifyEmbedUrl: null,
        spotifyArtistId: null,
        spotifyTrackIds: [],
        members: [],
      ),
    );
  }

  @override
  Future<Result<void>> acceptInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  }) async {
    decisions.add(('accept', invitationId, expectedSessionKey));
    if (throwDecision) throw StateError('Offline');
    return invitationId == currentId
        ? const Result.success(null)
        : const Result.failure(
            AppError(code: '9220', message: 'Bu davet artık geçerli değil.'),
          );
  }

  @override
  Future<Result<void>> rejectInvite({
    required String bandId,
    String? expectedSessionKey,
    String? invitationId,
  }) async {
    decisions.add(('reject', invitationId, expectedSessionKey));
    return invitationId == currentId
        ? const Result.success(null)
        : const Result.failure(
            AppError(code: '9220', message: 'Bu davet artık geçerli değil.'),
          );
  }
}

class _Sessions extends Fake implements AuthSessionManager {
  AuthSession current = AuthSession.authenticated(
    token: 'token',
    userId: 'account',
    username: 'account',
    accountStatus: 'ACTIVE',
    roles: ['ROLE_MUSICIAN'],
    permissions: [],
    expiresAt: DateTime.utc(2040),
    isAdmin: false,
  );
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

class _Api extends Fake implements ApiClient {
  Object? response;
  String? path;
  int calls = 0;
  Map<String, dynamic>? query;
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
    this.path = path;
    this.query = query;
    context = requestContext;
    return decoder!(response);
  }
}
