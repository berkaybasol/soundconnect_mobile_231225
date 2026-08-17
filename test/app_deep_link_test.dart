import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_route_guard.dart';
import 'package:soundconnect_23_12_25codx/app/router/app_routes.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/app_deep_link.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/app_deep_link_policy.dart';
import 'package:soundconnect_23_12_25codx/core/deep_link/pending_app_deep_link_store.dart';

const _listingId = '550e8400-e29b-41d4-a716-446655440000';
const _otherListingId = '01890f9e-7b2c-7d4a-8c3f-123456789abc';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppDeepLinkParser', () {
    test('accepts the canonical HTTPS URL and private app fallback', () {
      expect(
        AppDeepLinkParser.parse(
          Uri.parse(
            'https://soundconnect.com.tr/is-birligi/ilan/'
            '550E8400-E29B-41D4-A716-446655440000/?utm_source=whatsapp',
          ),
        ),
        const AppDeepLinkTarget.listing(listingId: _listingId),
      );
      expect(
        AppDeepLinkParser.parse(
          Uri.parse('soundconnect://is-birligi/ilan/$_listingId'),
        ),
        const AppDeepLinkTarget.listing(listingId: _listingId),
      );
    });

    test('rejects look-alike hosts, unsafe schemes and invalid paths', () {
      final rejected = <String>[
        'http://soundconnect.com.tr/is-birligi/ilan/$_listingId',
        'https://www.soundconnect.com.tr/is-birligi/ilan/$_listingId',
        'https://soundconnect.com.tr.evil.test/is-birligi/ilan/$_listingId',
        'https://user@soundconnect.com.tr/is-birligi/ilan/$_listingId',
        'https://soundconnect.com.tr:444/is-birligi/ilan/$_listingId',
        'https://soundconnect.com.tr/is-birligi/ilan/not-a-uuid',
        'https://soundconnect.com.tr/is-birligi/ilan/'
            '00000000-0000-0000-0000-000000000000',
        'https://soundconnect.com.tr/is-birligi/ilan/$_listingId/more',
        'https://soundconnect.com.tr/is-birligi/ilan',
        'soundconnect://evil.test/ilan/$_listingId',
        'soundconnect://is-birligi/other/$_listingId',
      ];

      for (final raw in rejected) {
        expect(AppDeepLinkParser.parse(Uri.parse(raw)), isNull, reason: raw);
      }
    });
  });

  group('resolveAppDeepLinkAccess', () {
    test('requests authentication for guests', () {
      expect(
        resolveAppDeepLinkAccess(const AuthSession.guest()),
        AppDeepLinkAccess.requestAuthentication,
      );
    });

    test('opens Collab only for an active supported profile role', () {
      expect(
        resolveAppDeepLinkAccess(_session(role: 'ROLE_MUSICIAN')),
        AppDeepLinkAccess.openCollab,
      );
      expect(
        resolveAppDeepLinkAccess(_session(role: 'ROLE_LISTENER')),
        AppDeepLinkAccess.unavailable,
      );
      expect(
        resolveAppDeepLinkAccess(
          _session(role: 'ROLE_VENUE', accountStatus: 'PENDING_VENUE_REQUEST'),
        ),
        AppDeepLinkAccess.unavailable,
      );
    });
  });

  test('anonymous auth routes preserve a pending guest link', () {
    for (final route in <String>{
      AppRoutes.login,
      AppRoutes.register,
      AppRoutes.forgotPassword,
      AppRoutes.otpVerify,
      AppRoutes.venueApplication,
      AppRoutes.venuePending,
      AppRoutes.studioPending,
      AppRoutes.studioRejected,
    }) {
      expect(AppRouteGuard.isAnonymousFlowRoute(route), isTrue);
    }
    expect(AppRouteGuard.isAnonymousFlowRoute(AppRoutes.home), isFalse);
  });

  group('SharedPreferencesPendingAppDeepLinkStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('persists a validated target across store instances', () async {
      final now = DateTime.utc(2026, 8, 14, 10);
      final first = SharedPreferencesPendingAppDeepLinkStore(clock: () => now);
      final link = PendingAppDeepLink(
        target: const AppDeepLinkTarget.listing(listingId: _listingId),
        createdAt: now,
      );
      await first.write(link);

      final restored = await SharedPreferencesPendingAppDeepLinkStore(
        clock: () => now.add(const Duration(minutes: 5)),
      ).read();

      expect(restored?.target.listingId, _listingId);
      expect(restored?.createdAt, now);
    });

    test('expires old links and removes corrupt values', () async {
      final now = DateTime.utc(2026, 8, 14, 10);
      final store = SharedPreferencesPendingAppDeepLinkStore(
        clock: () => now,
        ttl: const Duration(hours: 24),
      );
      await store.write(
        PendingAppDeepLink(
          target: const AppDeepLinkTarget.listing(listingId: _listingId),
          createdAt: now.subtract(const Duration(hours: 24)),
        ),
      );
      expect(await store.read(), isNull);

      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('sc_pending_app_deep_link_v1', '{broken');
      expect(await store.read(), isNull);
      expect(preferences.getString('sc_pending_app_deep_link_v1'), isNull);
    });

    test('completion of an older link cannot erase a newer link', () async {
      final now = DateTime.utc(2026, 8, 14, 10, 2);
      final store = SharedPreferencesPendingAppDeepLinkStore(clock: () => now);
      final older = PendingAppDeepLink(
        target: const AppDeepLinkTarget.listing(listingId: _listingId),
        createdAt: DateTime.utc(2026, 8, 14, 10),
      );
      final newer = PendingAppDeepLink(
        target: const AppDeepLinkTarget.listing(listingId: _otherListingId),
        createdAt: DateTime.utc(2026, 8, 14, 10, 1),
      );
      await store.write(older);
      await store.write(newer);

      await store.clearIfMatches(older);

      expect((await store.read())?.target.listingId, _otherListingId);
    });
  });

  group('AppDeepLinkInbox', () {
    test('deduplicates native cold/warm delivery and consumes once', () async {
      var now = DateTime.utc(2026, 8, 14, 10);
      final store = MemoryPendingAppDeepLinkStore();
      final inbox = AppDeepLinkInbox(store: store, clock: () => now);
      const target = AppDeepLinkTarget.listing(listingId: _listingId);

      final first = await inbox.record(target);
      now = now.add(const Duration(milliseconds: 500));
      final duplicate = await inbox.record(target);

      expect(first, isNotNull);
      expect(duplicate, isNull);
      expect((await inbox.pending())?.target, target);

      final claim = await inbox.claim();
      expect(claim.status, AppDeepLinkClaimStatus.acquired);
      await inbox.complete(claim.link!);
      expect(await inbox.pending(), isNull);

      now = now.add(const Duration(seconds: 2));
      expect(await inbox.record(target), isNotNull);
    });

    test('keeps the process copy when durable storage fails', () async {
      final inbox = AppDeepLinkInbox(store: _FailingPendingStore());
      const target = AppDeepLinkTarget.listing(listingId: _listingId);

      final recorded = await inbox.record(target);

      expect(recorded, isNotNull);
      expect((await inbox.pending())?.target, target);
      final claim = await inbox.claim();
      expect(claim.status, AppDeepLinkClaimStatus.acquired);
      await inbox.complete(claim.link!);
      expect(await inbox.pending(), isNull);
    });

    test('allows only one concurrent navigation claim', () async {
      final inbox = AppDeepLinkInbox(store: MemoryPendingAppDeepLinkStore());
      await inbox.record(
        const AppDeepLinkTarget.listing(listingId: _listingId),
      );

      final attempts = await Future.wait(<Future<AppDeepLinkClaim>>[
        inbox.claim(),
        inbox.claim(),
      ]);
      final acquired = attempts.singleWhere(
        (attempt) => attempt.status == AppDeepLinkClaimStatus.acquired,
      );

      expect(
        attempts.where(
          (attempt) => attempt.status == AppDeepLinkClaimStatus.acquired,
        ),
        hasLength(1),
      );
      expect(
        attempts.where(
          (attempt) => attempt.status == AppDeepLinkClaimStatus.busy,
        ),
        hasLength(1),
      );

      await inbox.release(acquired.link!);
      final retry = await inbox.claim();
      expect(retry.status, AppDeepLinkClaimStatus.acquired);
      await inbox.complete(retry.link!);
      expect((await inbox.claim()).status, AppDeepLinkClaimStatus.empty);
    });

    test(
      'completing an old claim preserves a link recorded afterwards',
      () async {
        var now = DateTime.utc(2026, 8, 14, 10);
        final inbox = AppDeepLinkInbox(
          store: MemoryPendingAppDeepLinkStore(),
          clock: () => now,
        );
        await inbox.record(
          const AppDeepLinkTarget.listing(listingId: _listingId),
        );
        final olderClaim = await inbox.claim();
        expect(olderClaim.status, AppDeepLinkClaimStatus.acquired);

        now = now.add(const Duration(minutes: 1));
        await inbox.record(
          const AppDeepLinkTarget.listing(listingId: _otherListingId),
        );
        await inbox.complete(olderClaim.link!);

        expect((await inbox.pending())?.target.listingId, _otherListingId);
        final newerClaim = await inbox.claim();
        expect(newerClaim.status, AppDeepLinkClaimStatus.acquired);
        expect(newerClaim.link?.target.listingId, _otherListingId);
      },
    );

    test('serializes writes so an older target cannot win a race', () async {
      var now = DateTime.utc(2026, 8, 14, 10);
      final store = _ReorderingPendingStore();
      final inbox = AppDeepLinkInbox(store: store, clock: () => now);

      final olderWrite = inbox.record(
        const AppDeepLinkTarget.listing(listingId: _listingId),
      );
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(seconds: 1));
      final newerWrite = inbox.record(
        const AppDeepLinkTarget.listing(listingId: _otherListingId),
      );
      store.releaseOlderWrite();
      await Future.wait(<Future<PendingAppDeepLink?>>[olderWrite, newerWrite]);

      expect(store.value?.target.listingId, _otherListingId);
      expect((await inbox.pending())?.target.listingId, _otherListingId);
    });
  });
}

class _FailingPendingStore implements PendingAppDeepLinkStore {
  @override
  Future<void> clearIfMatches(PendingAppDeepLink expected) {
    throw StateError('storage unavailable');
  }

  @override
  Future<PendingAppDeepLink?> read() {
    throw StateError('storage unavailable');
  }

  @override
  Future<void> write(PendingAppDeepLink link) {
    throw StateError('storage unavailable');
  }
}

class _ReorderingPendingStore implements PendingAppDeepLinkStore {
  final _firstWrite = Completer<void>();
  int _writes = 0;
  PendingAppDeepLink? value;

  void releaseOlderWrite() => _firstWrite.complete();

  @override
  Future<void> write(PendingAppDeepLink link) async {
    _writes += 1;
    if (_writes == 1) await _firstWrite.future;
    value = link;
  }

  @override
  Future<PendingAppDeepLink?> read() async => value;

  @override
  Future<void> clearIfMatches(PendingAppDeepLink expected) async {
    if (value?.identity == expected.identity) value = null;
  }
}

AuthSession _session({required String role, String accountStatus = 'ACTIVE'}) =>
    AuthSession.authenticated(
      token: 'token',
      userId: 'user-id',
      username: 'user',
      accountStatus: accountStatus,
      roles: <String>[role],
      permissions: const <String>[],
      expiresAt: DateTime.utc(2030),
      isAdmin: false,
    );
