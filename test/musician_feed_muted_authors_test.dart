import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/network/api_exception.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/data/musician_feed_muted_authors_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_muted_authors.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_muted_authors_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_muted_authors_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/screens/musician_feed_muted_authors_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _failure = AppError(code: 'offline', message: 'Bağlantı kurulamadı.');

void main() {
  group('muted author contract and repository', () {
    test('parses canonical profile identities and cursor', () {
      final page = MusicianFeedMutedAuthorsPage.fromJson(
        _wirePage([
          _wireAuthor('a', type: 'BAND'),
          _wireAuthor('a', type: 'MUSICIAN'),
        ], cursor: 'opaque+/='),
      );
      expect(page.items.map((item) => item.identity), [
        (profileType: 'BAND', profileId: 'a'),
        (profileType: 'MUSICIAN', profileId: 'a'),
      ]);
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'opaque+/=');
    });

    test('unavailable accounts discard stale names and avatars', () {
      final author = MusicianFeedMutedAuthor.fromJson({
        ..._wireAuthor('a'),
        'available': false,
        'displayName': 'Private name',
        'avatarUrl': 'https://example.com/private.jpg',
      });
      expect(author.displayName, isNull);
      expect(author.avatarUrl, isNull);
      expect(author.visibleName, 'Kullanılamayan hesap');
      expect(author.visibleAvatarUrl, isNull);
    });

    test(
      'unsafe avatars fall back while malformed identities and pages fail',
      () {
        final author = MusicianFeedMutedAuthor.fromJson({
          ..._wireAuthor('a'),
          'avatarUrl': 'javascript:alert(1)',
        });
        expect(author.visibleAvatarUrl, isNull);
        expect(
          () => MusicianFeedMutedAuthor.fromJson(_wireAuthor('../a')),
          throwsFormatException,
        );
        expect(
          () => MusicianFeedMutedAuthor.fromJson({
            ..._wireAuthor('a'),
            'mutedAt': '2026-09-13',
          }),
          throwsFormatException,
        );
        expect(
          () => MusicianFeedMutedAuthorsPage.fromJson({
            'items': [],
            'hasMore': true,
            'nextCursor': null,
          }),
          throwsFormatException,
        );
      },
    );

    test(
      'GET and DELETE bind current user and token with bounded opaque paging',
      () async {
        final sessions = _sessions();
        addTearDown(sessions.dispose);
        final notifications = <MusicianFeedAuthorProfileIdentity>[];
        final api = RecordingApiClient(
          (request) =>
              request.method == RecordedHttpMethod.get ? _wirePage([]) : null,
        );
        final repository = MusicianFeedMutedAuthorsRepositoryImpl(
          api,
          sessions,
          onUnmuted: notifications.add,
        );
        expect((await repository.load(cursor: 'opaque+/=')).isSuccess, isTrue);
        expect(api.lastRequest.path, '/api/v1/feed/musician/muted-authors');
        expect(api.lastRequest.query, {'limit': 30, 'cursor': 'opaque+/='});
        expect(api.lastRequest.requestContext?.expectedSessionKey, 'viewer');
        expect(api.lastRequest.requestContext?.expectedToken, 'token-a');
        expect(
          (await repository.unmute(
            profileType: ' band ',
            profileId: 'same-id',
          )).isSuccess,
          isTrue,
        );
        expect(api.lastRequest.method, RecordedHttpMethod.delete);
        expect(
          api.lastRequest.path,
          '/api/v1/feed/musician/authors/BAND/same-id/mute',
        );
        expect(notifications, [(profileType: 'BAND', profileId: 'same-id')]);
        final count = api.requests.length;
        for (final limit in [0, 51]) {
          expect((await repository.load(limit: limit)).isSuccess, isFalse);
        }
        expect((await repository.load(cursor: '')).isSuccess, isFalse);
        expect(
          (await repository.unmute(
            profileType: 'UNKNOWN',
            profileId: 'a',
          )).isSuccess,
          isFalse,
        );
        expect(api.requests.length, count);
      },
    );

    test('account changes fence both load and mutation callbacks', () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final read = Completer<Object?>();
      final write = Completer<Object?>();
      final notifications = <MusicianFeedAuthorProfileIdentity>[];
      final api = RecordingApiClient(
        (request) => request.method == RecordedHttpMethod.get
            ? read.future
            : write.future,
      );
      final repository = MusicianFeedMutedAuthorsRepositoryImpl(
        api,
        sessions,
        onUnmuted: notifications.add,
      );
      final loading = repository.load();
      final unmuting = repository.unmute(
        profileType: 'MUSICIAN',
        profileId: 'a',
      );
      sessions.replace(
        audienceSession(user: 'other', token: 'token-b', role: 'ROLE_MUSICIAN'),
      );
      read.complete(_wirePage([_wireAuthor('a')]));
      write.complete(null);
      expect((await loading).isSuccess, isFalse);
      expect((await unmuting).isSuccess, isFalse);
      expect(notifications, isEmpty);
    });

    test(
      'failed DELETE and unauthorized role send no success notification',
      () async {
        final sessions = _sessions();
        addTearDown(sessions.dispose);
        final notifications = <MusicianFeedAuthorProfileIdentity>[];
        final api = RecordingApiClient((_) => throw ApiException(_failure));
        final repository = MusicianFeedMutedAuthorsRepositoryImpl(
          api,
          sessions,
          onUnmuted: notifications.add,
        );
        expect(
          (await repository.unmute(
            profileType: 'MUSICIAN',
            profileId: 'a',
          )).error,
          _failure,
        );
        sessions.replace(
          audienceSession(
            user: 'viewer',
            token: 'token-a',
            role: 'ROLE_LISTENER',
          ),
        );
        expect((await repository.load()).isSuccess, isFalse);
        expect(api.requests.length, 1);
        expect(notifications, isEmpty);
      },
    );

    test(
      'repository invalidation survives closing the management cubit during DELETE',
      () async {
        final sessions = _sessions();
        addTearDown(sessions.dispose);
        final write = Completer<Object?>();
        final notifications = <MusicianFeedAuthorProfileIdentity>[];
        final repository = MusicianFeedMutedAuthorsRepositoryImpl(
          RecordingApiClient(
            (request) => request.method == RecordedHttpMethod.get
                ? _wirePage([_wireAuthor('a')])
                : write.future,
          ),
          sessions,
          onUnmuted: notifications.add,
        );
        final cubit = MusicianFeedMutedAuthorsCubit(repository, sessions);
        await cubit.initialize();
        final unmuting = cubit.unmute(_author('a').identity);
        await cubit.close();
        write.complete(null);
        expect(await unmuting, isFalse);
        expect(notifications, [_author('a').identity]);
      },
    );
  });

  group('muted author management state', () {
    test('a new screen state reloads server-persisted mute records', () async {
      final sessions = _sessions();
      addTearDown(sessions.dispose);
      final repository = _Repository()
        ..reads.addAll([
          Future.value(Result.success(_page([_author('a')]))),
          Future.value(Result.success(_page([_author('a')]))),
        ]);
      final first = MusicianFeedMutedAuthorsCubit(repository, sessions);
      await first.initialize();
      await first.close();
      final second = MusicianFeedMutedAuthorsCubit(repository, sessions);
      addTearDown(second.close);
      await second.initialize();
      expect(second.state.items.single.identity, _author('a').identity);
      expect(repository.cursors, [null, null]);
    });

    test(
      'paging is single flight and deduplicates by full profile identity',
      () async {
        final page = Completer<Result<MusicianFeedMutedAuthorsPage>>();
        final repository = _Repository()
          ..reads.addAll([
            Future.value(Result.success(_page([_author('a')], cursor: 'next'))),
            page.future,
          ]);
        final cubit = _cubit(repository);
        await cubit.initialize();
        final loading = cubit.loadMore();
        await cubit.loadMore();
        page.complete(
          Result.success(_page([_author('a'), _author('a', type: 'BAND')])),
        );
        await loading;
        expect(repository.cursors, [null, 'next']);
        expect(cubit.state.items.length, 2);
        expect(cubit.state.loadingMore, isFalse);
      },
    );

    test(
      'initial errors retry and stale refresh responses cannot replace newer results',
      () async {
        final old = Completer<Result<MusicianFeedMutedAuthorsPage>>();
        final repository = _Repository()
          ..reads.addAll([
            Future.value(const Result.failure(_failure)),
            old.future,
            Future.value(Result.success(_page([_author('fresh')]))),
          ]);
        final cubit = _cubit(repository);
        await cubit.initialize();
        expect(cubit.state.status, MusicianFeedMutedAuthorsStatus.failure);
        final stale = cubit.refresh();
        await cubit.refresh();
        old.complete(Result.success(_page([_author('old')])));
        await stale;
        expect(cubit.state.items.single.identity.profileId, 'fresh');
      },
    );

    test(
      'expired cursor starts one clean first page and preserves rows if refresh fails',
      () async {
        final repository = _Repository()
          ..reads.addAll([
            Future.value(
              Result.success(_page([_author('a')], cursor: 'expired')),
            ),
            Future.value(
              const Result.failure(AppError(code: '1318', message: 'Expired')),
            ),
            Future.value(const Result.failure(_failure)),
          ]);
        final cubit = _cubit(repository);
        await cubit.initialize();
        await cubit.loadMore();
        expect(repository.cursors, [null, 'expired', null]);
        expect(cubit.state.items.single.identity.profileId, 'a');
        expect(cubit.state.hasMore, isFalse);
        expect(cubit.state.refreshing, isFalse);
        expect(cubit.state.actionError, _failure);
      },
    );

    test('paging errors retain rows and reject a repeated cursor', () async {
      final repository = _Repository()
        ..reads.addAll([
          Future.value(Result.success(_page([_author('a')], cursor: 'same'))),
          Future.value(const Result.failure(_failure)),
          Future.value(Result.success(_page([_author('b')], cursor: 'same'))),
        ]);
      final cubit = _cubit(repository);
      await cubit.initialize();
      await cubit.loadMore();
      expect(cubit.state.pagingError, _failure);
      await cubit.loadMore();
      expect(
        cubit.state.pagingError?.code,
        'musician_feed_muted_authors_invalid_page',
      );
      expect(cubit.state.items.single.identity.profileId, 'a');
    });

    for (final succeeds in [false, true]) {
      test(
        'unmute prevents duplicate writes and ${succeeds ? 'removes' : 'retains'} the row',
        () async {
          final write = Completer<Result<void>>();
          final repository = _Repository()
            ..reads.add(Future.value(Result.success(_page([_author('a')]))))
            ..write = write.future;
          final callbacks = <MusicianFeedAuthorProfileIdentity>[];
          final cubit = _cubit(repository, onUnmuted: callbacks.add);
          await cubit.initialize();
          final unmuting = cubit.unmute(_author('a').identity);
          expect(await cubit.unmute(_author('a').identity), isFalse);
          expect(repository.unmutes.length, 1);
          expect(cubit.state.items.length, 1);
          expect(cubit.state.pendingAuthors, {_author('a').identity});
          write.complete(
            succeeds
                ? const Result.success(null)
                : const Result.failure(_failure),
          );
          expect(await unmuting, succeeds);
          expect(cubit.state.items.length, succeeds ? 0 : 1);
          expect(cubit.state.pendingAuthors, isEmpty);
          expect(callbacks.length, succeeds ? 1 : 0);
          expect(cubit.state.actionError, succeeds ? isNull : _failure);
        },
      );
    }

    test(
      'a stale refresh cannot restore an author after accepted unmute',
      () async {
        final old = Completer<Result<MusicianFeedMutedAuthorsPage>>();
        final repository = _Repository()
          ..reads.addAll([
            Future.value(Result.success(_page([_author('a')]))),
            old.future,
          ]);
        final cubit = _cubit(repository);
        await cubit.initialize();
        final refreshing = cubit.refresh();
        expect(await cubit.unmute(_author('a').identity), isTrue);
        old.complete(Result.success(_page([_author('a')])));
        await refreshing;
        expect(cubit.state.items, isEmpty);
      },
    );

    test(
      'a later authoritative refresh can show a profile muted again',
      () async {
        final repository = _Repository()
          ..reads.addAll([
            Future.value(Result.success(_page([_author('a')]))),
            Future.value(Result.success(_page([_author('a')]))),
          ]);
        final cubit = _cubit(repository);
        await cubit.initialize();
        expect(await cubit.unmute(_author('a').identity), isTrue);
        expect(cubit.state.items, isEmpty);
        await cubit.refresh();
        expect(cubit.state.items.single.identity, _author('a').identity);
      },
    );

    test(
      'account switch synchronously removes stale rows and forbids their DELETE',
      () async {
        final sessions = _sessions();
        addTearDown(sessions.dispose);
        final repository = _Repository()
          ..reads.add(Future.value(Result.success(_page([_author('a')]))));
        final cubit = MusicianFeedMutedAuthorsCubit(repository, sessions);
        addTearDown(cubit.close);
        await cubit.initialize();
        sessions.replace(
          audienceSession(
            user: 'other',
            token: 'token-b',
            role: 'ROLE_MUSICIAN',
          ),
        );
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.pendingAuthors, isEmpty);
        expect(await cubit.unmute(_author('a').identity), isFalse);
        expect(repository.unmutes, isEmpty);
      },
    );

    test(
      'silent identity replacement also rejects a stale row before I/O',
      () async {
        final sessions = _sessions();
        addTearDown(sessions.dispose);
        final repository = _Repository()
          ..reads.add(Future.value(Result.success(_page([_author('a')]))));
        final cubit = MusicianFeedMutedAuthorsCubit(repository, sessions);
        addTearDown(cubit.close);
        await cubit.initialize();
        sessions.current = audienceSession(
          user: 'other',
          token: 'token-b',
          role: 'ROLE_MUSICIAN',
        );
        expect(await cubit.unmute(_author('a').identity), isFalse);
        expect(repository.unmutes, isEmpty);
      },
    );

    test(
      'role revocation clears rows and fences an in-flight DELETE success',
      () async {
        final sessions = _sessions();
        addTearDown(sessions.dispose);
        final write = Completer<Result<void>>();
        final repository = _Repository()
          ..reads.add(Future.value(Result.success(_page([_author('a')]))))
          ..write = write.future;
        final callbacks = <MusicianFeedAuthorProfileIdentity>[];
        final cubit = MusicianFeedMutedAuthorsCubit(
          repository,
          sessions,
          onUnmuted: callbacks.add,
        );
        addTearDown(cubit.close);
        await cubit.initialize();
        final unmuting = cubit.unmute(_author('a').identity);
        sessions.replace(
          audienceSession(
            user: 'viewer',
            token: 'token-a',
            role: 'ROLE_LISTENER',
          ),
        );
        expect(cubit.state.items, isEmpty);
        expect(cubit.state.pendingAuthors, isEmpty);
        write.complete(const Result.success(null));
        expect(await unmuting, isFalse);
        expect(callbacks, isEmpty);
        await cubit.refresh();
        expect(repository.cursors.length, 1);
      },
    );
  });

  group('muted author screen', () {
    testWidgets(
      'shows loading, retry, persisted rows and empty state after unmute',
      (tester) async {
        final initial = Completer<Result<MusicianFeedMutedAuthorsPage>>();
        final repository = _Repository()
          ..reads.addAll([
            initial.future,
            Future.value(Result.success(_page([_author('a')]))),
          ]);
        await _pump(tester, repository);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        initial.complete(const Result.failure(_failure));
        await tester.pumpAndSettle();
        expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
        await tester.tap(find.text('Tekrar dene'));
        await tester.pumpAndSettle();
        expect(find.text('Author a'), findsOneWidget);
        await tester.tap(find.text('Sessizi kaldır'));
        await tester.pumpAndSettle();
        expect(
          find.text('Akışında sessize aldığın hesap yok.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'large text at 320dp preserves private fallback and accessible unmute',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final repository = _Repository()
            ..reads.add(
              Future.value(
                Result.success(
                  _page([
                    MusicianFeedMutedAuthor(
                      identity: _author('a').identity,
                      available: false,
                      mutedAt: DateTime.utc(2026),
                      displayName: 'Private name',
                      avatarUrl: 'https://example.com/private.jpg',
                    ),
                  ]),
                ),
              ),
            );
          await _pump(tester, repository, scale: 2);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Private name'), findsNothing);
          final image = tester.widget<AppCachedNetworkImage>(
            find.byType(AppCachedNetworkImage),
          );
          expect(image.imageUrl, isNull);
          final action = find.bySemanticsLabel(
            'Kullanılamayan hesap: Sessizi kaldır',
          );
          await tester.ensureVisible(find.text('Sessizi kaldır'));
          await tester.pumpAndSettle();
          final node = tester.getSemantics(action);
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
          await tester.tap(find.text('Sessizi kaldır'));
          await tester.pumpAndSettle();
          expect(repository.unmutes, [_author('a').identity]);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('failed unmute keeps its row and exposes retryable button', (
      tester,
    ) async {
      final write = Completer<Result<void>>();
      final repository = _Repository()
        ..reads.add(Future.value(Result.success(_page([_author('a')]))))
        ..write = write.future;
      await _pump(tester, repository);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sessizi kaldır'));
      await tester.pump();
      expect(find.text('Kaldırılıyor…'), findsOneWidget);
      write.complete(const Result.failure(_failure));
      await tester.pumpAndSettle();
      expect(find.text('Author a'), findsOneWidget);
      expect(find.text('Sessizi kaldır'), findsOneWidget);
      expect(find.text('Bağlantı kurulamadı.'), findsOneWidget);
    });
  });
}

AudienceTestSessions _sessions() => AudienceTestSessions(
  audienceSession(user: 'viewer', token: 'token-a', role: 'ROLE_MUSICIAN'),
);

MusicianFeedMutedAuthorsCubit _cubit(
  _Repository repository, {
  void Function(MusicianFeedAuthorProfileIdentity)? onUnmuted,
}) {
  final sessions = _sessions();
  addTearDown(sessions.dispose);
  final cubit = MusicianFeedMutedAuthorsCubit(
    repository,
    sessions,
    onUnmuted: onUnmuted,
  );
  addTearDown(cubit.close);
  return cubit;
}

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  double scale = 1,
}) async {
  final sessions = _sessions();
  addTearDown(sessions.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: MusicianFeedMutedAuthorsScreen(
        repository: repository,
        sessions: sessions,
      ),
    ),
  );
}

MusicianFeedMutedAuthor _author(String id, {String type = 'MUSICIAN'}) =>
    MusicianFeedMutedAuthor(
      identity: (profileType: type, profileId: id),
      available: true,
      mutedAt: DateTime.utc(2026, 9, 13),
      displayName: 'Author $id',
    );

MusicianFeedMutedAuthorsPage _page(
  List<MusicianFeedMutedAuthor> items, {
  String? cursor,
}) => MusicianFeedMutedAuthorsPage(
  items: items,
  nextCursor: cursor,
  hasMore: cursor != null,
);

Map<String, Object?> _wireAuthor(String id, {String type = 'MUSICIAN'}) => {
  'profileType': type,
  'profileId': id,
  'available': true,
  'mutedAt': '2026-09-13T10:00:00Z',
  'displayName': 'Author $id',
  'avatarUrl': null,
};
Map<String, Object?> _wirePage(
  List<Map<String, Object?>> items, {
  String? cursor,
}) => {'items': items, 'nextCursor': cursor, 'hasMore': cursor != null};

class _Repository implements MusicianFeedMutedAuthorsRepository {
  final reads = <Future<Result<MusicianFeedMutedAuthorsPage>>>[];
  final cursors = <String?>[];
  final unmutes = <MusicianFeedAuthorProfileIdentity>[];
  Future<Result<void>>? write;

  @override
  Future<Result<MusicianFeedMutedAuthorsPage>> load({
    int limit = 30,
    String? cursor,
  }) {
    cursors.add(cursor);
    return reads.removeAt(0);
  }

  @override
  Future<Result<void>> unmute({
    required String profileType,
    required String profileId,
  }) {
    unmutes.add((profileType: profileType, profileId: profileId));
    return write ?? Future.value(const Result.success(null));
  }
}
