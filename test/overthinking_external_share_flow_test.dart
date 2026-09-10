import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_share_tile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_data.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_flow.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_service.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/share/overthinking_share_sheet.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';

import 'support/event_audience_fakes.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
);
final _sheet = find.byKey(const Key('overthinking-share-sheet'));
final _other = find.byKey(const Key('overthinking-share-target-other'));
const _notFound = Result<OverthinkingPost>.failure(
  AppError(code: '404', message: 'Yazı bulunamadı.'),
);

void main() {
  testWidgets('fresh source produces a preview before explicit target export', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final future = h.share(postId: '  post  ');
    await tester.pumpAndSettle();
    expect(h.posts.reads, ['post']);
    expect(h.exporter.prepared.single.content, _source().content);
    expect(_sheet, findsOneWidget);
    expect(h.exporter.sent, isEmpty);
    await _choose(tester);
    await future;
    expect(h.posts.reads, ['post', 'post']);
    expect(h.exporter.sent.single.target, EventShareTarget.other);
    expect(h.exporter.sent.single.prepared, same(h.exporter.results.single));
    expect(h.exporter.sent.single.isValid?.call(), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing preview never exports and another tap can reopen', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    for (var i = 0; i < 2; i++) {
      final future = h.share();
      await tester.pumpAndSettle();
      await _close(tester);
      await future;
    }
    expect(h.posts.reads, ['post', 'post']);
    expect(h.exporter.prepared, hasLength(2));
    expect(h.exporter.sent, isEmpty);
  });

  testWidgets('rapid taps share one source read and one preview', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final first = h.share();
    final second = h.share();
    await tester.pumpAndSettle();
    expect(h.posts.reads, ['post']);
    expect(h.exporter.prepared, hasLength(1));
    expect(_sheet, findsOneWidget);
    await _close(tester);
    await Future.wait([first, second]);
  });

  testWidgets('anonymous source never prepares locally revealed identity', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    h.posts.current = _source().copyWith(
      anonymous: true,
      canViewAuthor: true,
      authorUsername: 'privately-visible-name',
    );
    final future = h.share();
    await tester.pumpAndSettle();
    final data = h.exporter.prepared.single;
    expect(data.authorLabel, 'Anonim yazar');
    expect(data.authorAvatarUrl, isNull);
    expect(data.accessibilityDescription, isNot(contains('privately-visible')));
    await _choose(tester);
    await future;
    expect(h.exporter.sent.single.prepared.data.authorLabel, 'Anonim yazar');
  });

  test('prepared image is an immutable copy of its source bytes', () {
    final original = Uint8List.fromList(_pixel);
    final prepared = PreparedOverthinkingShare(
      bytes: original,
      data: OverthinkingShareData.fromPost(_source()),
    );
    final first = prepared.bytes.first;
    original[0] = 0;
    expect(prepared.bytes.first, first);
    expect(() => prepared.bytes[0] = 0, throwsUnsupportedError);
  });

  testWidgets('mismatched prepared data cannot show or export another source', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    h.exporter.onPrepare = (_) async => PreparedOverthinkingShare(
      bytes: _pixel,
      data: OverthinkingShareData.fromPost(_source().copyWith(id: 'other')),
    );
    await h.share();
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(h.exporter.sent, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed preparation releases the guard for an explicit retry', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    h.exporter.onPrepare = (_) async => throw StateError('Rendering failed');
    await h.share();
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(h.exporter.sent, isEmpty);
    h.exporter.onPrepare = null;
    final retry = h.share();
    await tester.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    expect(h.posts.reads, ['post', 'post']);
    await _close(tester);
    await retry;
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'real profile tile footer previews fresh source without owner note',
    (tester) async {
      final h = await _Harness.mount(tester);
      await _mountTile(tester, h);
      final footer = find.byKey(
        const Key('listener-overthinking-external-share-publication'),
      );
      await tester.ensureVisible(footer);
      await tester.tap(footer);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      expect(h.posts.reads, ['post']);
      expect(h.exporter.prepared.single.content, _source().content);
      expect(
        h.exporter.prepared.single.accessibilityDescription,
        isNot(contains('Bu paylaşımı kendi profilimde yorumladım.')),
      );
      expect(h.exporter.sent, isEmpty);
      await _choose(tester);
      expect(h.posts.reads, ['post', 'post']);
      expect(h.exporter.sent.single.target, EventShareTarget.other);
      expect(tester.takeException(), isNull);
    },
  );

  for (final action in [
    'repository invalidation',
    'row replacement',
    'row removal',
  ]) {
    testWidgets('real tile $action dismisses only its stale external preview', (
      tester,
    ) async {
      final h = await _Harness.mount(tester);
      final tile = await _mountTile(tester, h);
      final footer = find.byKey(
        const Key('listener-overthinking-external-share-publication'),
      );
      await tester.ensureVisible(footer);
      await tester.tap(footer);
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      if (action == 'repository invalidation') {
        tile.repository.changes.value++;
      } else if (action == 'row replacement') {
        tile.row.value = _tileShare(title: 'New profile projection');
      } else {
        tile.row.value = null;
      }
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
      expect(h.exporter.sent, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final entry in <String, Result<OverthinkingPost>>{
    'wrong source id': Result.success(_source().copyWith(id: 'other-post')),
    'deleted source': _notFound,
  }.entries) {
    testWidgets('${entry.key} on first read never creates a preview', (
      tester,
    ) async {
      final h = await _Harness.mount(tester);
      h.posts.onRead = (_) async => entry.value;
      await h.share();
      await tester.pumpAndSettle();
      expect(h.exporter.prepared, isEmpty);
      expect(_sheet, findsNothing);
      expect(h.exporter.sent, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final stage in ['fetch', 'prepare', 'selected source revalidation']) {
    for (final change in ['account', 'token']) {
      testWidgets('$change change during $stage cancels the old export', (
        tester,
      ) async {
        final h = await _Harness.mount(tester);
        final source = Completer<Result<OverthinkingPost>>();
        final preparation = Completer<PreparedOverthinkingShare>();
        if (stage == 'fetch') h.posts.onRead = (_) => source.future;
        if (stage == 'prepare') {
          h.exporter.onPrepare = (_) => preparation.future;
        }
        final future = h.share();
        await tester.pumpAndSettle();
        if (stage == 'selected source revalidation') {
          h.posts.onRead = (_) => source.future;
          await _choose(tester);
          expect(h.posts.reads, hasLength(2));
        }
        h.sessions.replace(
          change == 'account'
              ? audienceSession(user: 'another-listener')
              : audienceSession(token: 'rotated-token'),
        );
        if (stage == 'prepare') {
          preparation.complete(
            PreparedOverthinkingShare(
              bytes: _pixel,
              data: h.exporter.prepared.single,
            ),
          );
        } else {
          source.complete(Result.success(_source()));
        }
        await future;
        await tester.pumpAndSettle();
        expect(_sheet, findsNothing);
        expect(h.exporter.sent, isEmpty);
        if (stage == 'fetch') expect(h.exporter.prepared, isEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final change in ['account', 'token', 'source row removed']) {
    testWidgets('$change dismisses an open preview without platform handoff', (
      tester,
    ) async {
      final h = await _Harness.mount(tester);
      final future = h.share();
      await tester.pumpAndSettle();
      expect(_sheet, findsOneWidget);
      if (change == 'source row removed') {
        h.validity.value = false;
      } else {
        h.sessions.replace(
          change == 'account'
              ? const AuthSession.guest()
              : audienceSession(token: 'new-token'),
        );
      }
      await tester.pumpAndSettle();
      await future;
      expect(_sheet, findsNothing);
      expect(h.exporter.sent, isEmpty);
      expect(ModalRoute.of(h.context)!.isCurrent, isTrue);
    });
  }

  testWidgets('invalidated covered preview removes only its own route', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final future = h.share();
    await tester.pumpAndSettle();
    final navigator = Navigator.of(h.context);
    final covering = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Text('Newer screen')),
    );
    unawaited(navigator.push(covering));
    await tester.pumpAndSettle();
    h.validity.value = false;
    await tester.pumpAndSettle();
    await future;
    expect(find.text('Newer screen'), findsOneWidget);
    expect(covering.isCurrent, isTrue);
    expect(
      find.byKey(const Key('overthinking-share-sheet'), skipOffstage: false),
      findsNothing,
    );
    expect(h.exporter.sent, isEmpty);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(ModalRoute.of(h.context)!.isCurrent, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid before sheet first frame removes the exact preview', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final future = showOverthinkingShareSheet(
      h.context,
      PreparedOverthinkingShare(
        bytes: _pixel,
        data: OverthinkingShareData.fromPost(_source()),
      ),
      validityChanges: h.validity,
      isValid: () => h.validity.value,
    );
    h.validity.value = false;
    await tester.pumpAndSettle();
    expect(await future, isNull);
    expect(_sheet, findsNothing);
    expect(ModalRoute.of(h.context)!.isCurrent, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final entry in <String, Result<OverthinkingPost>>{
    'title changed': Result.success(_source().copyWith(title: 'Yeni başlık')),
    'content changed': Result.success(
      _source().copyWith(content: 'Yeni içerik'),
    ),
    'became anonymous': Result.success(_source().copyWith(anonymous: true)),
    'different source': Result.success(_source().copyWith(id: 'different')),
    'deleted source': _notFound,
  }.entries) {
    testWidgets('${entry.key} after preview prevents exporting obsolete art', (
      tester,
    ) async {
      final h = await _Harness.mount(tester);
      final future = h.share();
      await tester.pumpAndSettle();
      h.posts.onRead = (_) async => entry.value;
      await _choose(tester);
      await future;
      expect(h.posts.reads, ['post', 'post']);
      expect(h.exporter.sent, isEmpty);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('counter changes after preview allow the exact prepared image', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    final future = h.share();
    await tester.pumpAndSettle();
    h.posts.current = _source().copyWith(
      likeCount: 999,
      commentCount: 88,
      likedByMe: true,
      revealRequestPending: true,
    );
    await _choose(tester);
    await future;
    expect(h.exporter.sent.single.prepared, same(h.exporter.results.single));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'blank ids, stale expected session and invalid row cannot start',
    (tester) async {
      final h = await _Harness.mount(tester);
      await h.share(postId: '  ');
      await h.share(expectedSession: audienceSession(token: 'stale-token'));
      h.validity.value = false;
      await h.share();
      expect(h.posts.reads, isEmpty);
      expect(h.exporter.prepared, isEmpty);
    },
  );

  testWidgets('covered and disposed contexts cannot begin a new share', (
    tester,
  ) async {
    final h = await _Harness.mount(tester);
    unawaited(
      Navigator.of(h.context).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Newer screen')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await h.share();
    await tester.pumpWidget(const SizedBox.shrink());
    await h.share();
    expect(h.posts.reads, isEmpty);
    expect(h.exporter.prepared, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final action in ['cover', 'dispose']) {
    testWidgets('$action during source read cannot open a delayed preview', (
      tester,
    ) async {
      final h = await _Harness.mount(tester);
      final read = Completer<Result<OverthinkingPost>>();
      h.posts.onRead = (_) => read.future;
      final future = h.share();
      await tester.pump();
      if (action == 'cover') {
        unawaited(
          Navigator.of(h.context).push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Newer screen')),
            ),
          ),
        );
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      await tester.pumpAndSettle();
      read.complete(Result.success(_source()));
      await future;
      await tester.pumpAndSettle();
      expect(h.exporter.prepared, isEmpty);
      expect(h.exporter.sent, isEmpty);
      expect(_sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'export guard remains session and source bound at platform handoff',
    (tester) async {
      final h = await _Harness.mount(tester);
      final future = h.share();
      await tester.pumpAndSettle();
      await _choose(tester);
      await future;
      final guard = h.exporter.sent.single.isValid!;
      expect(guard(), isTrue);
      h.validity.value = false;
      expect(guard(), isFalse);
      h.validity.value = true;
      h.sessions.replace(audienceSession(token: 'rotated-token'));
      expect(guard(), isFalse);
    },
  );
}

Future<({_Shares repository, ValueNotifier<OverthinkingProfileShare?> row})>
_mountTile(WidgetTester tester, _Harness h) async {
  await serviceLocator.reset();
  addTearDown(() => serviceLocator.reset());
  serviceLocator.registerSingleton<OverthinkingRepository>(h.posts);
  serviceLocator.registerSingleton<OverthinkingShareService>(h.exporter);
  final repository = _Shares();
  final row = ValueNotifier<OverthinkingProfileShare?>(_tileShare());
  addTearDown(row.dispose);
  addTearDown(repository.changes.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy,
      home: ListenerProfileTheme(
        child: Scaffold(
          body: SingleChildScrollView(
            child: ValueListenableBuilder<OverthinkingProfileShare?>(
              valueListenable: row,
              builder: (_, share, _) => share == null
                  ? const SizedBox.shrink()
                  : ListenerOverthinkingShareTile(
                      share: share,
                      username: 'listener',
                      ownerUserId: 'listener',
                      repository: repository,
                      sessions: h.sessions,
                      isCurrent: () => true,
                      onRefresh: () async {},
                      onRemoved: (_) {},
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (repository: repository, row: row);
}

OverthinkingProfileShare _tileShare({
  String title = 'Old profile projection',
}) => OverthinkingProfileShare(
  shareId: 'publication',
  note: 'Bu paylaşımı kendi profilimde yorumladım.',
  publishedAt: DateTime.utc(2026, 9, 10),
  post: _source().copyWith(
    title: title,
    content: 'The cached excerpt must not become the export.',
    anonymous: true,
    authorAvatarUrl: null,
    spotifyAlbumImageUrl: null,
  ),
);

class _Shares extends Fake implements OverthinkingProfileShareRepository {
  @override
  final ValueNotifier<int> changes = ValueNotifier(0);
}

Future<void> _choose(WidgetTester tester) async {
  await tester.ensureVisible(_other);
  await tester.tap(_other);
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.ensureVisible(find.byTooltip('Kapat'));
  await tester.tap(find.byTooltip('Kapat'));
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness(this.context, this.sessions);

  final BuildContext context;
  final AudienceTestSessions sessions;
  final validity = ValueNotifier(true);
  final posts = _Posts();
  final exporter = _Exporter();

  static Future<_Harness> mount(WidgetTester tester) async {
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
    final h = _Harness(host, AudienceTestSessions(audienceSession()));
    addTearDown(h.sessions.dispose);
    addTearDown(h.validity.dispose);
    return h;
  }

  Future<void> share({String postId = 'post', AuthSession? expectedSession}) =>
      shareOverthinkingPost(
        context,
        postId: postId,
        sessions: sessions,
        expectedSession: expectedSession ?? sessions.session,
        repository: posts,
        shareService: exporter,
        isValid: () => validity.value,
        validityChanges: validity,
      );
}

class _Posts extends Fake implements OverthinkingRepository {
  final reads = <String>[];
  OverthinkingPost current = _source();
  Future<Result<OverthinkingPost>> Function(int read)? onRead;

  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) {
    reads.add(postId);
    return onRead?.call(reads.length) ?? Future.value(Result.success(current));
  }
}

class _Exporter extends Fake implements OverthinkingShareService {
  final prepared = <OverthinkingShareData>[];
  final results = <PreparedOverthinkingShare>[];
  final sent =
      <
        ({
          PreparedOverthinkingShare prepared,
          EventShareTarget target,
          bool Function()? isValid,
        })
      >[];
  Future<PreparedOverthinkingShare> Function(OverthinkingShareData)? onPrepare;

  @override
  Future<PreparedOverthinkingShare> prepare(
    BuildContext context,
    OverthinkingShareData data,
  ) async {
    prepared.add(data);
    final result =
        await onPrepare?.call(data) ??
        PreparedOverthinkingShare(bytes: _pixel, data: data);
    results.add(result);
    return result;
  }

  @override
  Future<void> share(
    BuildContext context,
    PreparedOverthinkingShare prepared,
    EventShareTarget target, {
    bool Function()? isValid,
  }) async {
    sent.add((prepared: prepared, target: target, isValid: isValid));
  }
}

OverthinkingPost _source() => OverthinkingPostModel.fromJson({
  'id': 'post',
  'title': 'Bir şarkının içinde',
  'content': 'Belki bir başkası da tam böyle hissediyordur.',
  'authorId': 'author',
  'authorUsername': 'berna',
  'authorAvatarUrl': 'https://example.com/avatar.png',
  'anonymous': false,
  'canViewAuthor': true,
  'visibilityType': 'VISIBLE',
  'spotifyTrackName': 'BRLN',
  'spotifyArtistName': 'Şair',
  'spotifyAlbumImageUrl': 'https://example.com/album.png',
});
