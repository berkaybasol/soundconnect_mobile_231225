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
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/data/band_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/band_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_member_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_pending_invitation.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/band_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/musician_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/musician_profile_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/band_management_panel_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

void main() {
  group('founder pending invitation repository contract', () {
    test(
      'default read is paginated and carries expected account fence',
      () async {
        final api = _Api();
        final result = await BandRepositoryImpl(api).getPendingInvitations(
          bandId: ' band ',
          expectedSessionKey: ' founder ',
        );
        expect(result.isSuccess, isTrue);
        expect(api.calls, hasLength(1));
        expect(api.calls.single.method, ApiHttpMethod.get);
        expect(
          api.calls.single.path,
          '/api/v1/user/bands/band/invitations/pending',
        );
        expect(api.calls.single.query, {'page': 0, 'size': 20});
        expect(api.calls.single.context?.expectedSessionKey, 'founder');
        expect(api.calls.single.body, isNull);
        expect(result.data!.items.single.userId, 'aedrum-user');
        expect(result.data!.items.single.username, 'aedrum');
        expect(result.data!.items.single.profilePictureUrl, isNull);
        expect(result.data!.page, 0);
        expect(result.data!.size, 20);
        expect(result.data!.totalElements, 1);
        expect(result.data!.hasNext, isFalse);
        expect(() => result.data!.items.clear(), throwsUnsupportedError);
      },
    );

    test(
      'profilePicture wire value is mapped without needing a public profile read',
      () async {
        final api = _Api()
          ..response = _wirePage([
            _wireItem()..['profilePicture'] = 'https://example.test/aedrum.jpg',
          ]);
        final result = await _read(api);
        expect(
          result.data!.items.single.profilePictureUrl,
          'https://example.test/aedrum.jpg',
        );
        expect(api.calls, hasLength(1));
      },
    );

    for (final invalid in [
      (page: -1, size: 20),
      (page: 10001, size: 1),
      (page: 0, size: 0),
      (page: 0, size: 51),
      (page: 5001, size: 20),
    ]) {
      test('invalid page bounds $invalid fail before transport', () async {
        final api = _Api();
        final result = await BandRepositoryImpl(api).getPendingInvitations(
          bandId: 'band',
          page: invalid.page,
          size: invalid.size,
          expectedSessionKey: 'founder',
        );
        expect(result.isSuccess, isFalse);
        expect(api.calls, isEmpty);
      });
    }

    test('maximum permitted page and offset remain readable', () async {
      final api = _Api()
        ..response = _wirePage(
          [_wireItem()],
          page: 10000,
          size: 10,
          total: 100001,
        );
      final result = await BandRepositoryImpl(api).getPendingInvitations(
        bandId: 'band',
        page: 10000,
        size: 10,
        expectedSessionKey: 'founder',
      );
      expect(result.isSuccess, isTrue);
      expect(result.data!.page, 10000);
      expect(result.data!.hasNext, isFalse);
    });

    for (final invalid in [
      (band: '', account: 'founder'),
      (band: '../other-band', account: 'founder'),
      (band: 'band?all=true', account: 'founder'),
      (band: 'band', account: ' '),
    ]) {
      test(
        'invalid private target/account $invalid never dispatches',
        () async {
          final api = _Api();
          final result = await BandRepositoryImpl(api).getPendingInvitations(
            bandId: invalid.band,
            expectedSessionKey: invalid.account,
          );
          expect(result.isSuccess, isFalse);
          expect(api.calls, isEmpty);
        },
      );
    }

    for (final response in <Object?>[
      null,
      <Object>[],
      _wirePage([_wireItem()])..['page'] = 1,
      _wirePage([_wireItem()])..['number'] = 1,
      _wirePage([_wireItem()])..['size'] = 10,
      _wirePage([_wireItem()])..['totalElements'] = -1,
      _wirePage([_wireItem()])..['totalPages'] = 2,
      _wirePage([_wireItem()])..['first'] = false,
      _wirePage([_wireItem()])..['last'] = false,
      _wirePage([], total: 1),
      _wirePage([_wireItem()], total: 2),
      _wirePage([_wireItem()], total: 21),
      _wirePage([_wireItem()])..remove('content'),
      _wirePage([_wireItem(), _wireItem()]),
      _wirePage([_wireItem()..['status'] = 'ACTIVE']),
      _wirePage([_wireItem()..['status'] = 'LEFT']),
      _wirePage([_wireItem()..remove('status')]),
      _wirePage([_wireItem()..['userId'] = ' ']),
      _wirePage([_wireItem()..['username'] = ' ']),
      _wirePage([42]),
    ]) {
      test('malformed private page fails closed $response', () async {
        final api = _Api()..response = response;
        final result = await _read(api);
        expect(result.isSuccess, isFalse);
        expect(result.data, isNull);
      });
    }

    test(
      'empty out-of-range page is valid after concurrent invitation acceptance',
      () async {
        final api = _Api()..response = _wirePage([], page: 1, total: 0);
        final result = await BandRepositoryImpl(api).getPendingInvitations(
          bandId: 'band',
          page: 1,
          expectedSessionKey: 'founder',
        );
        expect(result.isSuccess, isTrue);
        expect(result.data!.items, isEmpty);
        expect(result.data!.hasNext, isFalse);
      },
    );

    test(
      'unsupported fenced API cannot fall back to an unfenced GET',
      () async {
        final api = _UnfencedApi();
        final result = await BandRepositoryImpl(
          api,
        ).getPendingInvitations(bandId: 'band', expectedSessionKey: 'founder');
        expect(result.isSuccess, isFalse);
        expect(api.reads, 0);
      },
    );

    for (final code in ['403', 'session_changed', 'band_not_found']) {
      test('private read error $code is preserved', () async {
        final error = AppError(
          code: code,
          message: 'Cannot view pending invitations',
        );
        final api = _Api()..failure = ApiException(error);
        final result = await _read(api);
        expect(result.isSuccess, isFalse);
        expect(result.error, same(error));
      });
    }
  });

  group('pending invitation section in members workspace', () {
    late _Bands bands;
    late _SessionManager session;
    setUp(() async {
      await serviceLocator.reset();
      bands = _Bands();
      session = _SessionManager();
      serviceLocator
        ..registerSingleton<BandRepository>(bands)
        ..registerSingleton<AuthSessionManager>(session)
        ..registerSingleton<MusicianProfileRepository>(_Musicians());
    });
    tearDown(serviceLocator.reset);

    testWidgets('pending read is separate from active members and read-only', (
      tester,
    ) async {
      await _mount(tester, bands);
      expect(bands.pendingReads, hasLength(1));
      expect(bands.pendingReads.single, (
        bandId: 'band',
        page: 0,
        size: 20,
        account: 'founder',
      ));
      expect(find.byKey(const Key('band-member-founder')), findsOneWidget);
      expect(find.byKey(const Key('band-member-aedrum-user')), findsNothing);
      await _reveal(tester, const Key('band-pending-aedrum-user'));
      expect(find.text('Bekleyen Davetler'), findsOneWidget);
      expect(find.text('Onay bekliyor'), findsOneWidget);
      expect(find.text('aedrum'), findsOneWidget);
      final pending = find.byKey(const Key('band-pending-aedrum-user'));
      expect(
        find.descendant(of: pending, matching: find.byType(InkWell)),
        findsNothing,
      );
      expect(
        find.descendant(of: pending, matching: find.byType(IconButton)),
        findsNothing,
      );
      expect(find.byKey(const Key('member-options-aedrum-user')), findsNothing);
      expect(
        find.byKey(const Key('edit-member-title-aedrum-user')),
        findsNothing,
      );
      expect(find.byKey(const Key('remove-member-aedrum-user')), findsNothing);
      expect(bands.mutations, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('successful empty page leaves no empty pending section', (
      tester,
    ) async {
      bands.onPending = (_) async => Result.success(_page([]));
      await _mount(tester, bands);
      expect(find.byKey(const Key('band-pending-section')), findsNothing);
      expect(find.text('Bekleyen Davetler'), findsNothing);
      expect(find.byKey(const Key('band-member-founder')), findsOneWidget);
      expect(bands.pendingReads, hasLength(1));
    });

    for (final viewer in <String, AuthSession>{
      'guest': const AuthSession.guest(),
      'ordinary member': _session(user: 'aedrum-user'),
      'outsider': _session(user: 'outsider'),
      'suspended founder': _session(status: 'SUSPENDED'),
      'wrong-role founder': _session(role: 'ROLE_LISTENER'),
    }.entries) {
      testWidgets('${viewer.key} cannot fetch or see pending invitations', (
        tester,
      ) async {
        session.current = viewer.value;
        await _mount(tester, bands);
        expect(bands.pendingReads, isEmpty);
        expect(find.byKey(const Key('band-pending-section')), findsNothing);
        expect(find.text('aedrum'), findsNothing);
      });
    }

    testWidgets('loading pending list never hides the active roster', (
      tester,
    ) async {
      final pending = Completer<Result<BandPendingInvitationPage>>();
      bands.onPending = (_) => pending.future;
      await _mount(tester, bands, settle: false);
      expect(find.byKey(const Key('band-member-founder')), findsOneWidget);
      await _reveal(tester, const Key('band-pending-loading'), settle: false);
      expect(find.byKey(const Key('band-pending-loading')), findsOneWidget);
      pending.complete(Result.success(_page([_invitation()])));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('band-pending-loading')), findsNothing);
      expect(find.byKey(const Key('band-pending-aedrum-user')), findsOneWidget);
      expect(bands.pendingReads, hasLength(1));
    });

    testWidgets('first-page failure stays local and retry succeeds once', (
      tester,
    ) async {
      bands.onPending = (_) async => const Result.failure(_offline);
      await _mount(tester, bands);
      expect(find.byKey(const Key('band-member-founder')), findsOneWidget);
      await _reveal(tester, const Key('band-pending-retry'));
      final retry = tester
          .widget<TextButton>(find.byKey(const Key('band-pending-retry')))
          .onPressed!;
      final pending = Completer<Result<BandPendingInvitationPage>>();
      bands.onPending = (_) => pending.future;
      retry();
      retry();
      await tester.pump();
      expect(bands.pendingReads, hasLength(2));
      pending.complete(Result.success(_page([_invitation()])));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('band-pending-aedrum-user')), findsOneWidget);
      expect(find.byKey(const Key('band-pending-retry')), findsNothing);
    });

    testWidgets(
      'overlapping next page triggers one fresh first page without stale append',
      (tester) async {
        final pending = Completer<Result<BandPendingInvitationPage>>();
        bands.onPending = (call) {
          if (call.page == 1) return pending.future;
          return Future.value(
            Result.success(
              bands.pendingReads.length == 1
                  ? _page(
                      [_invitation(), ..._invitations(19)],
                      total: 22,
                      hasNext: true,
                    )
                  : _page([
                      _invitation(id: 'fresh-user', username: 'yeniliste'),
                    ]),
            ),
          );
        };
        await _mount(tester, bands);
        expect(bands.pendingReads, hasLength(1));
        await _reveal(tester, const Key('band-pending-more'));
        final more = tester
            .widget<TextButton>(find.byKey(const Key('band-pending-more')))
            .onPressed!;
        more();
        more();
        await tester.pump();
        expect(bands.pendingReads.map((read) => read.page), [0, 1]);
        pending.complete(
          Result.success(
            _page(
              [_invitation(), _invitation(id: 'new-user', username: 'yeniuye')],
              page: 1,
              total: 22,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(bands.pendingReads.map((read) => read.page), [0, 1, 0]);
        await _reveal(tester, const Key('band-pending-fresh-user'));
        expect(
          find.byKey(const Key('band-pending-fresh-user')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('band-pending-aedrum-user')), findsNothing);
        expect(find.byKey(const Key('band-pending-new-user')), findsNothing);
        expect(find.byKey(const Key('band-pending-more')), findsNothing);
        await tester.pumpAndSettle();
        expect(bands.pendingReads, hasLength(3));
        expect(bands.mutations, 0);
      },
    );

    testWidgets('shrinking count with empty tail reloads first page once', (
      tester,
    ) async {
      bands.onPending = (call) async => Result.success(
        call.page == 1
            ? _page([], page: 1, total: 20)
            : bands.pendingReads.length == 1
            ? _page(
                [_invitation(), ..._invitations(19)],
                total: 21,
                hasNext: true,
              )
            : _page(_invitations(20)),
      );
      await _mount(tester, bands);
      await _reveal(tester, const Key('band-pending-more'));
      await tester.tap(find.byKey(const Key('band-pending-more')));
      await tester.pumpAndSettle();
      expect(bands.pendingReads.map((read) => read.page), [0, 1, 0]);
      await _reveal(tester, const Key('band-pending-pending-19'));
      expect(find.byKey(const Key('band-pending-pending-19')), findsOneWidget);
      expect(find.byKey(const Key('band-pending-aedrum-user')), findsNothing);
      expect(find.byKey(const Key('band-pending-more')), findsNothing);
      expect(find.byKey(const Key('band-pending-retry')), findsNothing);
      expect(bands.mutations, 0);
    });

    testWidgets('load-more failure retains rows and retries the same page', (
      tester,
    ) async {
      bands.onPending = (call) async => call.page == 0
          ? Result.success(_page([_invitation()], total: 21, hasNext: true))
          : const Result.failure(_offline);
      await _mount(tester, bands);
      await _reveal(tester, const Key('band-pending-more'));
      await tester.tap(find.byKey(const Key('band-pending-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('band-pending-aedrum-user')), findsOneWidget);
      await _reveal(tester, const Key('band-pending-retry'));
      bands.onPending = (call) async => Result.success(
        _page([_invitation(id: 'new-user')], page: call.page, total: 21),
      );
      await tester.tap(find.byKey(const Key('band-pending-retry')));
      await tester.pumpAndSettle();
      expect(bands.pendingReads.map((read) => read.page), [0, 1, 1]);
      await _reveal(tester, const Key('band-pending-new-user'));
      expect(find.byKey(const Key('band-pending-new-user')), findsOneWidget);
    });

    testWidgets(
      'refresh reconciles accepted invitation into active roster only',
      (tester) async {
        await _mount(tester, bands);
        await _reveal(tester, const Key('band-pending-aedrum-user'));
        bands.profile = _profile(includeAedrum: true);
        bands.onPending = (_) async => Result.success(_page([]));
        await tester.tap(find.byTooltip('Üyeleri yenile'));
        await tester.pumpAndSettle();
        await _reveal(tester, const Key('band-member-aedrum-user'));
        expect(
          find.byKey(const Key('band-member-aedrum-user')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('band-pending-aedrum-user')), findsNothing);
        expect(find.byKey(const Key('band-pending-section')), findsNothing);
        expect(bands.pendingReads.map((read) => read.page), [0, 0]);
        expect(bands.mutations, 0);
      },
    );

    testWidgets('refresh fences an older in-flight private list response', (
      tester,
    ) async {
      final old = Completer<Result<BandPendingInvitationPage>>();
      bands.onPending = (_) => bands.pendingReads.length == 1
          ? old.future
          : Future.value(
              Result.success(
                _page([_invitation(id: 'fresh-user', username: 'freshname')]),
              ),
            );
      await _mount(tester, bands, settle: false);
      // A real profile read decodes a fresh snapshot, even if values match.
      bands.profile = _profile();
      await tester.tap(find.byTooltip('Üyeleri yenile'));
      await tester.pumpAndSettle();
      expect(bands.pendingReads.map((read) => read.page), [0, 0]);
      old.complete(Result.success(_page([_invitation()])));
      await tester.pumpAndSettle();
      await _reveal(tester, const Key('band-pending-fresh-user'));
      expect(find.byKey(const Key('band-pending-fresh-user')), findsOneWidget);
      expect(find.byKey(const Key('band-pending-aedrum-user')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'resume while member menu is open refreshes once after closing',
      (tester) async {
        await _mount(tester, bands);
        final initialProfileReads = bands.profileReads;
        await tester.tap(find.byKey(const Key('member-options-founder')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('edit-member-title-founder')),
          findsOneWidget,
        );
        bands.profile = _profile(includeAedrum: true);
        bands.onPending = (_) async => Result.success(_page([]));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
        expect(bands.profileReads, initialProfileReads);
        expect(bands.pendingReads, hasLength(1));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(bands.profileReads, initialProfileReads + 1);
        expect(bands.pendingReads.map((read) => read.page), [0, 0]);
        await _reveal(tester, const Key('band-member-aedrum-user'));
        expect(
          find.byKey(const Key('band-member-aedrum-user')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('band-pending-aedrum-user')), findsNothing);
        expect(find.byKey(const Key('band-pending-section')), findsNothing);
        expect(bands.mutations, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'session change discards a refresh queued behind a member menu',
      (tester) async {
        await _mount(tester, bands);
        final initialProfileReads = bands.profileReads;
        await tester.tap(find.byKey(const Key('member-options-founder')));
        await tester.pumpAndSettle();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        session.change(const AuthSession.guest());
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(bands.profileReads, initialProfileReads);
        expect(bands.pendingReads, hasLength(1));
        expect(find.byKey(const Key('band-pending-section')), findsNothing);
        expect(bands.mutations, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('filtered active users do not strand the next pending page', (
      tester,
    ) async {
      bands.profile = _profile(includeAedrum: true);
      bands.onPending = (call) async => Result.success(
        call.page == 0
            ? _page([_invitation()], total: 21, hasNext: true)
            : _page(
                [_invitation(id: 'waiting-user', username: 'bekleyen')],
                page: 1,
                total: 21,
              ),
      );
      await _mount(tester, bands);
      expect(find.byKey(const Key('band-pending-aedrum-user')), findsNothing);
      await _reveal(tester, const Key('band-pending-more'));
      await tester.tap(find.byKey(const Key('band-pending-more')));
      await tester.pumpAndSettle();
      expect(bands.pendingReads.map((read) => read.page), [0, 1]);
      await _reveal(tester, const Key('band-pending-waiting-user'));
      expect(
        find.byKey(const Key('band-pending-waiting-user')),
        findsOneWidget,
      );
      expect(bands.mutations, 0);
    });

    for (final next in <String, AuthSession>{
      'account': _session(user: 'other-founder'),
      'token': _session(token: 'replacement-token'),
      'status': _session(status: 'SUSPENDED'),
      'role': _session(role: 'ROLE_LISTENER'),
      'logout': const AuthSession.guest(),
    }.entries) {
      testWidgets('session ${next.key} drops late private invitation results', (
        tester,
      ) async {
        final pending = Completer<Result<BandPendingInvitationPage>>();
        bands.onPending = (_) => bands.pendingReads.length == 1
            ? pending.future
            : Future.value(Result.success(_page([])));
        await _mount(tester, bands, settle: false);
        expect(bands.pendingReads, hasLength(1));
        session.change(next.value);
        pending.complete(Result.success(_page([_invitation()])));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('band-pending-aedrum-user')), findsNothing);
        expect(find.text('aedrum'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('logout removes an already displayed private pending list', (
      tester,
    ) async {
      await _mount(tester, bands);
      await _reveal(tester, const Key('band-pending-aedrum-user'));
      session.change(const AuthSession.guest());
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('band-pending-section')), findsNothing);
      expect(find.text('aedrum'), findsNothing);
    });

    testWidgets(
      'disposal ignores late read without navigation or stale errors',
      (tester) async {
        final pending = Completer<Result<BandPendingInvitationPage>>();
        bands.onPending = (_) => pending.future;
        await _mount(tester, bands, settle: false);
        await tester.pumpWidget(const SizedBox.shrink());
        pending.complete(Result.success(_page([_invitation()])));
        await tester.pumpAndSettle();
        expect(find.text('aedrum'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    for (final scale in [1.0, 2.0]) {
      testWidgets('pending read-only card fits navy at320dp ${scale}x', (
        tester,
      ) async {
        bands.onPending = (_) async => Result.success(
          _page([_invitation(username: 'cokuzunbirmuzisyenkullaniciadi')]),
        );
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _mount(tester, bands, scale: scale);
        await _reveal(tester, const Key('band-pending-aedrum-user'));
        expect(tester.takeException(), isNull);
        final card = tester.getRect(
          find.byKey(const Key('band-pending-aedrum-user')),
        );
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(320));
        expect(find.byType(CustomScrollView), findsOneWidget);
        await _capture(tester, 'navy-$scale');
      });
    }
  });
}

const _offline = AppError(code: 'offline', message: 'Davetler yüklenemedi.');

Future<Result<BandPendingInvitationPage>> _read(_Api api) => BandRepositoryImpl(
  api,
).getPendingInvitations(bandId: 'band', expectedSessionKey: 'founder');

Map<String, dynamic> _wireItem() => {
  'userId': 'aedrum-user',
  'username': 'aedrum',
  'profilePicture': null,
  'status': 'PENDING',
};

Map<String, dynamic> _wirePage(
  List<Object?> content, {
  int page = 0,
  int size = 20,
  int? total,
}) {
  final elements = total ?? content.length;
  final pages = elements == 0 ? 0 : (elements + size - 1) ~/ size;
  return {
    'content': content,
    'page': page,
    'size': size,
    'totalElements': elements,
    'totalPages': pages,
    'first': page == 0,
    'last': pages == 0 || page + 1 >= pages,
  };
}

BandPendingInvitation _invitation({
  String id = 'aedrum-user',
  String username = 'aedrum',
}) => BandPendingInvitation(
  userId: id,
  username: username,
  profilePictureUrl: null,
);

List<BandPendingInvitation> _invitations(int count) => List.generate(
  count,
  (index) => _invitation(id: 'pending-$index', username: 'bekleyen$index'),
);

BandPendingInvitationPage _page(
  List<BandPendingInvitation> items, {
  int page = 0,
  int? total,
  bool hasNext = false,
}) => BandPendingInvitationPage(
  items: List.unmodifiable(items),
  page: page,
  size: 20,
  totalElements: total ?? items.length,
  hasNext: hasNext,
);

BandProfile _profile({bool includeAedrum = false}) => BandProfile(
  id: 'band',
  name: 'Şahbaz',
  description: null,
  profilePictureUrl: null,
  instagramUrl: null,
  youtubeUrl: null,
  soundCloudUrl: null,
  spotifyEmbedUrl: null,
  spotifyArtistId: null,
  spotifyTrackIds: const [],
  members: [
    const BandMemberSummary(
      userId: 'founder',
      profileId: 'founder-profile',
      username: 'bugrasahin',
      profilePictureUrl: null,
      role: 'FOUNDER',
      status: 'ACTIVE',
    ),
    if (includeAedrum)
      const BandMemberSummary(
        userId: 'aedrum-user',
        profileId: 'aedrum-profile',
        username: 'aedrum',
        profilePictureUrl: null,
        role: 'MEMBER',
        status: 'ACTIVE',
      ),
  ],
);

AuthSession _session({
  String user = 'founder',
  String token = 'token',
  String status = 'ACTIVE',
  String role = 'ROLE_MUSICIAN',
}) => AuthSession.authenticated(
  token: token,
  userId: user,
  username: user,
  accountStatus: status,
  roles: [role],
  permissions: const [],
  expiresAt: DateTime.utc(2040),
  isAdmin: false,
);

class _SessionManager extends Fake implements AuthSessionManager {
  AuthSession current = _session();
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

typedef _PendingRead = ({String bandId, int page, int size, String account});

class _Bands extends Fake implements BandRepository {
  BandProfile profile = _profile();
  final pendingReads = <_PendingRead>[];
  int profileReads = 0;
  int mutations = 0;
  Future<Result<BandPendingInvitationPage>> Function(_PendingRead)? onPending;
  @override
  Future<Result<BandProfile>> getBandById(String bandId) async {
    profileReads++;
    return Result.success(profile);
  }

  @override
  Future<Result<BandPendingInvitationPage>> getPendingInvitations({
    required String bandId,
    int page = 0,
    int size = 20,
    required String expectedSessionKey,
  }) async {
    final call = (
      bandId: bandId,
      page: page,
      size: size,
      account: expectedSessionKey,
    );
    pendingReads.add(call);
    return onPending == null
        ? Result.success(_page([_invitation()]))
        : onPending!(call);
  }

  @override
  Future<Result<void>> removeMember({
    required String bandId,
    required String userId,
    String? expectedSessionKey,
    int? expectedTitleVersion,
  }) async {
    mutations++;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> inviteMember({
    required String bandId,
    required String invitedUserId,
    String? message,
    String? expectedSessionKey,
  }) async {
    mutations++;
    return const Result.success(null);
  }
}

class _Musicians extends Fake implements MusicianProfileRepository {
  @override
  Future<Result<MusicianProfile>> getPublicProfileByProfileId(
    String id,
  ) async => const Result.failure(_offline);
}

typedef _ApiCall = ({
  ApiHttpMethod method,
  String path,
  Object? body,
  Map<String, dynamic>? query,
  ApiRequestContext? context,
});

class _Api extends ApiClient {
  Object? response = _wirePage([_wireItem()]);
  Object? failure;
  final calls = <_ApiCall>[];
  @override
  Future<T> request<T>(
    ApiHttpMethod method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
    ApiRequestContext? requestContext,
  }) async {
    calls.add((
      method: method,
      path: path,
      body: body,
      query: query,
      context: requestContext,
    ));
    if (failure case final error?) throw error;
    return decoder!(response);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnfencedApi extends ApiClient {
  int reads = 0;
  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    T Function(Object?)? decoder,
  }) async {
    reads++;
    return decoder!(_wirePage([_wireItem()]));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _mount(
  WidgetTester tester,
  _Bands bands, {
  double scale = 1,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('pending-preview'),
      child: MaterialApp(
        theme: AppTheme.navy,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: BandManagementPanelScreen(profile: bands.profile),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Üyeleri Yönet'));
  await tester.tap(find.text('Üyeleri Yönet'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _reveal(WidgetTester tester, Key key, {bool settle = true}) async {
  final target = find.byKey(key);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 20,
    );
  } else {
    await tester.ensureVisible(target);
  }
  if (settle) await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String suffix) async {
  if (!const bool.fromEnvironment('BAND_PENDING_PREVIEW')) return;
  await tester.runAsync(() async {
    const root = String.fromEnvironment('BAND_PENDING_PREVIEW_FLUTTER_ROOT');
    for (final entry in {
      'Roboto':
          '$root/engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf',
      'MaterialIcons':
          '$root/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            File(entry.value).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('pending-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/band-pending-$suffix.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
