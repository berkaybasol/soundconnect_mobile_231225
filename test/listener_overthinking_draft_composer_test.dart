import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/overthinking_profile_draft.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_profile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_draft_composer.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_share_card.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/gradient_outline_button.dart';

import 'support/event_audience_fakes.dart';

const _offline = AppError(code: 'network', message: 'Bağlantı kurulamadı.');
final _note = find.byKey(const Key('listener-overthinking-draft-note'));
final _publish = find.byKey(const Key('listener-overthinking-draft-publish'));
final _cancel = find.byKey(const Key('listener-overthinking-draft-cancel'));
final _reload = find.byKey(const Key('listener-overthinking-draft-reload'));
final _dialog = find.byKey(
  const Key('listener-overthinking-draft-leave-dialog'),
);

void main() {
  testWidgets(
    'fresh inline profile card loads source and state without writing, then publishes explicitly',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      expect(h.posts.reads, ['source']);
      expect(h.shares.reads, ['source']);
      expect(h.shares.notes, isEmpty);
      expect(find.byType(ListenerOverthinkingShareCard), findsOneWidget);
      expect(find.text('Taslak · Henüz paylaşılmadı'), findsOneWidget);
      expect(h.key.currentState!.readyForReveal, isTrue);
      await tester.enterText(_note, ' Bu sözler bana iyi geldi. ');
      expect(h.shares.notes, isEmpty);
      expect(h.key.currentState!.dirty, isTrue);
      await _tap(tester, _publish);
      expect(h.shares.notes, ['Bu sözler bana iyi geldi.']);
      expect(h.completed, [true]);
      expect(h.key.currentState!.requiresLeaveGuard, isFalse);
    },
  );

  testWidgets(
    'blank description publishes null and pristine cancel never writes',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await _tap(tester, _publish);
      expect(h.shares.notes, [null]);
      final canceled = _Harness();
      await canceled.mount(tester);
      await _tap(tester, _cancel);
      expect(canceled.completed, [false]);
      expect(canceled.shares.notes, isEmpty);
      expect(canceled.shares.deleted, isEmpty);
    },
  );

  testWidgets(
    'anonymous draft never exports an already revealed private author',
    (tester) async {
      final h = _Harness();
      h.posts.source = h.posts.source.copyWith(
        anonymous: true,
        canViewAuthor: true,
        authorId: 'secret',
        authorUsername: 'private-author',
        authorAvatarUrl: 'https://private.test/avatar',
      );
      await h.mount(tester);
      expect(find.textContaining('private-author'), findsNothing);
      expect(find.text('Anonim yazar'), findsOneWidget);
      expect(find.text('@listener'), findsOneWidget);
    },
  );

  testWidgets(
    'ANONYMOUS visibility type also masks an inconsistent legacy flag',
    (tester) async {
      final h = _Harness();
      h.posts.source = h.posts.source.copyWith(
        anonymous: false,
        visibilityType: 'ANONYMOUS',
        canViewAuthor: true,
        authorId: 'secret',
        authorUsername: 'private-author',
      );
      await h.mount(tester);
      expect(find.textContaining('private-author'), findsNothing);
      expect(find.text('Anonim yazar'), findsOneWidget);
    },
  );

  testWidgets(
    'dirty cancel asks once; keep retains text, discard writes nothing',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await tester.enterText(_note, 'Açıklamam kaybolmasın');
      final leave = h.key.currentState!.canLeave();
      await tester.pumpAndSettle();
      expect(_dialog, findsOneWidget);
      expect(await h.key.currentState!.canLeave(), isFalse);
      await _tap(tester, find.text('Düzenlemeye devam et'));
      expect(await leave, isFalse);
      expect(_text(tester), 'Açıklamam kaybolmasın');
      await _tap(tester, _cancel);
      await _tap(tester, find.text('Taslağı bırak'));
      expect(h.completed, [false]);
      expect(h.shares.notes, isEmpty);
    },
  );

  testWidgets(
    'duplicate publish and navigation during an in-flight write are blocked',
    (tester) async {
      final h = _Harness();
      final waiting = Completer<Result<OverthinkingProfileShareState>>();
      h.shares.onPublish = () => waiting.future;
      await h.mount(tester);
      final staleTap = tester
          .widget<GradientOutlineButton>(_publish)
          .onPressed!;
      staleTap();
      staleTap();
      await tester.pump();
      expect(h.shares.notes, hasLength(1));
      expect(h.key.currentState!.saving, isTrue);
      expect(await h.key.currentState!.canLeave(), isFalse);
      waiting.complete(Result.success(_state(published: true)));
      await tester.pumpAndSettle();
      expect(h.completed, [true]);
      staleTap();
      expect(h.shares.notes, hasLength(1));
    },
  );

  testWidgets(
    '500 Unicode code points accepted, 501 rejected and CRLF normalized',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      final max = List.filled(500, '🎵').join();
      await tester.enterText(_note, max);
      await tester.pump();
      expect(_text(tester).runes.length, 500);
      expect(find.text('500/500'), findsOneWidget);
      await tester.enterText(_note, '${max}x');
      expect(_text(tester), max);
      await tester.enterText(_note, 'Bir\r\nİki\rÜç');
      expect(_text(tester), 'Bir\nİki\nÜç');
      await _tap(tester, _publish);
      expect(h.shares.notes, ['Bir\nİki\nÜç']);
    },
  );

  for (final scenario in [
    'ghost',
    'other-owner',
    'musician',
    'mixed-role',
    'inactive',
    'onboarding',
    'hidden',
    'not-editable',
  ]) {
    testWidgets('$scenario draft never reads or writes', (tester) async {
      final session = scenario == 'musician'
          ? audienceSession(role: 'ROLE_MUSICIAN')
          : scenario == 'mixed-role'
          ? audienceSession(roles: ['ROLE_LISTENER', 'ROLE_MUSICIAN'])
          : scenario == 'inactive'
          ? audienceSession(status: 'INACTIVE')
          : audienceSession();
      final h = _Harness(
        session: session,
        profile: _profile(
          ghost: scenario == 'ghost',
          owner: scenario == 'other-owner' ? 'other' : 'listener',
          choice: scenario != 'onboarding',
          visible: scenario != 'hidden',
          editable: scenario != 'not-editable',
        ),
      );
      await h.mount(tester);
      expect(_note, findsNothing);
      expect(h.posts.reads, isEmpty);
      expect(h.shares.reads, isEmpty);
      expect(h.shares.notes, isEmpty);
    });
  }

  testWidgets(
    'source and share identity must both match the requested original',
    (tester) async {
      final h = _Harness();
      h.posts.source = h.posts.source.copyWith(id: 'different');
      await h.mount(tester);
      expect(find.byType(ListenerOverthinkingShareCard), findsNothing);
      expect(tester.widget<GradientOutlineButton>(_publish).onPressed, isNull);
      h.posts.source = _source();
      h.shares.current = _state(postId: 'different');
      await _tap(tester, _reload);
      expect(tester.widget<GradientOutlineButton>(_publish).onPressed, isNull);
      expect(h.shares.notes, isEmpty);
    },
  );

  testWidgets('source failure is retryable without an implied publication', (
    tester,
  ) async {
    final h = _Harness();
    h.posts.onRead = () async => const Result.failure(_offline);
    await h.mount(tester);
    expect(h.key.currentState!.readyForReveal, isTrue);
    expect(tester.widget<GradientOutlineButton>(_publish).onPressed, isNull);
    h.posts.onRead = null;
    await _tap(tester, _reload);
    expect(_note, findsOneWidget);
    expect(h.shares.notes, isEmpty);
  });

  testWidgets('server canPublish false disables a stale standard-profile CTA', (
    tester,
  ) async {
    final h = _Harness();
    h.shares.current = _state(canPublish: false);
    await h.mount(tester);
    expect(tester.widget<GradientOutlineButton>(_publish).onPressed, isNull);
    expect(
      find.textContaining('şu anda profilinde paylaşılamıyor'),
      findsOneWidget,
    );
    expect(h.shares.notes, isEmpty);
  });

  testWidgets(
    'existing publication note is read-only and removal addresses its exact share',
    (tester) async {
      final h = _Harness();
      h.shares.current = _state(
        published: true,
        note: 'Önceki açıklama',
        shareId: 'exact-share',
      );
      await h.mount(tester);
      expect(_note, findsNothing);
      expect(find.text('Önceki açıklama'), findsOneWidget);
      expect(h.key.currentState!.dirty, isFalse);
      expect(h.shares.notes, isEmpty);
      await _tap(
        tester,
        find.byKey(const Key('listener-overthinking-draft-remove')),
      );
      expect(h.shares.deleted, ['exact-share']);
      expect(h.posts.deleted, isEmpty);
      expect(h.completed, [false]);
    },
  );

  testWidgets(
    'ambiguous publish preserves description and reconciles without a second write',
    (tester) async {
      final h = _Harness();
      h.shares.onPublish = () async => const Result.failure(_offline);
      await h.mount(tester);
      await tester.enterText(_note, 'Benim açıklamam');
      await _tap(tester, _publish);
      expect(_text(tester), 'Benim açıklamam');
      expect(h.key.currentState!.requiresLeaveGuard, isTrue);
      expect(tester.widget<GradientOutlineButton>(_publish).onPressed, isNull);
      h.shares.current = _state(published: true, note: 'Benim açıklamam');
      await _tap(tester, _reload);
      expect(h.completed, [true]);
      expect(h.shares.notes, ['Benim açıklamam']);
    },
  );

  testWidgets(
    'uncommitted ambiguous publish keeps authored text until an explicit reviewed retry',
    (tester) async {
      final h = _Harness();
      h.shares.onPublish = () async => const Result.failure(_offline);
      await h.mount(tester);
      await tester.enterText(_note, 'Korunan açıklama');
      await _tap(tester, _publish);
      await _tap(tester, _reload);
      expect(_text(tester), 'Korunan açıklama');
      expect(h.completed, isEmpty);
      expect(h.shares.notes, hasLength(1));
      h.shares.onPublish = null;
      await _tap(tester, _publish);
      expect(h.shares.notes, ['Korunan açıklama', 'Korunan açıklama']);
      expect(h.completed, [true]);
    },
  );

  testWidgets(
    'uncertain deletion never automatically deletes a newer republication',
    (tester) async {
      final h = _Harness();
      h.shares.current = _state(published: true, shareId: 'old');
      h.shares.onDelete = () async => const Result.failure(_offline);
      await h.mount(tester);
      await _tap(
        tester,
        find.byKey(const Key('listener-overthinking-draft-remove')),
      );
      h.shares.current = _state(
        published: true,
        shareId: 'new',
        note: 'Yeni paylaşım',
      );
      await _tap(tester, _reload);
      expect(h.completed, isEmpty);
      expect(h.shares.deleted, ['old']);
      expect(find.text('Yeni paylaşım'), findsOneWidget);
      h.shares.onDelete = null;
      await _tap(
        tester,
        find.byKey(const Key('listener-overthinking-draft-remove')),
      );
      expect(h.shares.deleted, ['old', 'new']);
    },
  );

  for (final during in ['read', 'write', 'dialog']) {
    testWidgets(
      'same-user token replacement during $during clears private text and rejects late callbacks',
      (tester) async {
        final h = _Harness();
        final read = Completer<Result<OverthinkingPost>>();
        final write = Completer<Result<OverthinkingProfileShareState>>();
        if (during == 'read') h.posts.onRead = () => read.future;
        if (during == 'write') h.shares.onPublish = () => write.future;
        await h.mount(tester, settle: during != 'read');
        Future<bool>? leave;
        if (during != 'read') {
          await tester.enterText(_note, 'Özel açıklamam');
          if (during == 'write') {
            tester.widget<GradientOutlineButton>(_publish).onPressed!();
            await tester.pump();
          } else {
            leave = h.key.currentState!.canLeave();
            await tester.pumpAndSettle();
            expect(_dialog, findsOneWidget);
          }
        }
        h.sessions.replace(audienceSession(token: 'new-token'));
        if (during == 'read') read.complete(Result.success(_source()));
        if (during == 'write') {
          write.complete(
            Result.success(_state(published: true, note: 'Özel açıklamam')),
          );
        }
        await tester.pumpAndSettle();
        expect(_note, findsNothing);
        expect(_dialog, findsNothing);
        expect(find.textContaining('Özel açıklamam'), findsNothing);
        expect(h.completed, isEmpty);
        expect(await h.key.currentState!.canLeave(), isFalse);
        if (leave != null) expect(await leave, isFalse);
        expect(h.posts.reads, hasLength(1));
        expect(h.shares.reads, hasLength(1));
      },
    );
  }

  testWidgets(
    'ghost transition dismisses an open leave dialog and permanently invalidates the draft',
    (tester) async {
      final h = _Harness();
      await h.mount(tester);
      await tester.enterText(_note, 'Özel açıklama');
      final leave = h.key.currentState!.canLeave();
      await tester.pumpAndSettle();
      h.profile.value = _profile(ghost: true);
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
      expect(_note, findsNothing);
      expect(await leave, isFalse);
      h.profile.value = _profile();
      await tester.pumpAndSettle();
      expect(_note, findsNothing);
      expect(h.shares.notes, isEmpty);
      expect(h.posts.reads, hasLength(1));
    },
  );

  testWidgets(
    'lazy profile scrolling retains draft text and does not reload the original',
    (tester) async {
      final h = _Harness();
      await h.mount(tester, lazy: true);
      await tester.enterText(_note, 'Liste içinde korunan açıklama');
      await tester.pumpAndSettle();
      h.scroll.jumpTo(5000);
      await tester.pumpAndSettle();
      expect(h.key.currentState, isNotNull);
      h.scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(_text(tester), 'Liste içinde korunan açıklama');
      expect(h.posts.reads, hasLength(1));
      expect(h.shares.reads, hasLength(1));
    },
  );

  for (final scale in [1.0, 1.6]) {
    testWidgets('actual draft card fits 320px at $scale without layout errors', (
      tester,
    ) async {
      final h = _Harness();
      await h.mount(tester, width: 320, scale: scale);
      await tester.enterText(
        _note,
        'Bu yazıya uzun bir açıklama eklediğimde de profilin gerçek kartı içinde düzenleyebiliyorum.',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(_publish);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(h.shares.notes, isEmpty);
    });
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester) =>
    tester.widget<TextField>(_note).controller!.text;

OverthinkingPost _source() => OverthinkingPostModel.fromJson({
  'id': 'source',
  'title': 'Bazı şarkılar eve benziyor.',
  'content':
      'Bazen bir şarkı çalıyor ve kendimi yıllar önce bıraktığım bir yerde buluyorum. Aynı sokak, aynı his.',
  'anonymous': true,
  'visibilityType': 'ANONYMOUS',
  'canViewAuthor': false,
  'spotifyTrackName': 'Bir Derdim Var',
  'spotifyArtistName': 'mor ve ötesi',
});

OverthinkingProfileShareState _state({
  String postId = 'source',
  bool published = false,
  bool canPublish = true,
  String shareId = 'share',
  String? note,
}) => OverthinkingProfileShareState(
  postId: postId,
  shareId: published ? shareId : null,
  publishedOnProfile: published,
  note: published ? note : null,
  publishedAt: published ? DateTime.utc(2026, 9, 10) : null,
  canPublish: canPublish,
);

ListenerProfile _profile({
  bool ghost = false,
  String owner = 'listener',
  bool choice = true,
  bool visible = true,
  bool editable = true,
}) => ListenerProfile(
  id: 'profile',
  userId: owner,
  username: 'listener',
  bio: null,
  profilePictureUrl: null,
  followerCount: 0,
  followingCount: 0,
  visibilityMode: ghost
      ? ListenerVisibilityMode.ghost
      : ListenerVisibilityMode.standard,
  visibilityChoiceCompleted: choice,
  profileContentVisible: visible,
  profileContentEditable: editable,
);

class _Shares extends Fake implements OverthinkingProfileShareRepository {
  final signal = ValueNotifier(0);
  @override
  ValueListenable<int> get changes => signal;
  final reads = <String>[];
  final notes = <String?>[];
  final deleted = <String>[];
  OverthinkingProfileShareState current = _state();
  Future<Result<OverthinkingProfileShareState>> Function()? onRead;
  Future<Result<OverthinkingProfileShareState>> Function()? onPublish;
  Future<Result<void>> Function()? onDelete;
  @override
  Future<Result<OverthinkingProfileShareState>> getState({
    required String postId,
    required AuthSession expectedSession,
  }) async {
    reads.add(postId);
    return onRead?.call() ?? Result.success(current);
  }

  @override
  Future<Result<OverthinkingProfileShareState>> publish({
    required String postId,
    String? note,
    required AuthSession expectedSession,
  }) async {
    notes.add(note);
    return onPublish?.call() ??
        Result.success(current = _state(published: true, note: note));
  }

  @override
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  }) async {
    deleted.add(shareId);
    if (onDelete != null) return onDelete!();
    current = _state();
    return const Result.success(null);
  }
}

class _Posts extends Fake implements OverthinkingRepository {
  OverthinkingPost source = _source();
  final reads = <String>[];
  final deleted = <String>[];
  Future<Result<OverthinkingPost>> Function()? onRead;
  @override
  Future<Result<OverthinkingPost>> getDetail({required String postId}) async {
    reads.add(postId);
    return onRead?.call() ?? Result.success(source);
  }

  @override
  Future<Result<void>> deletePost({required String postId}) async {
    deleted.add(postId);
    return const Result.success(null);
  }
}

class _Harness {
  _Harness({AuthSession? session, ListenerProfile? profile}) {
    sessions = AudienceTestSessions(session ?? audienceSession());
    this.profile = ValueNotifier(profile ?? _profile());
    expected = sessions.session;
    addTearDown(() {
      sessions.dispose();
      this.profile.dispose();
      shares.signal.dispose();
      scroll.dispose();
    });
  }
  final shares = _Shares();
  final posts = _Posts();
  final completed = <bool>[];
  final key = GlobalKey<ListenerOverthinkingDraftComposerState>();
  final scroll = ScrollController();
  late final AudienceTestSessions sessions;
  late final ValueNotifier<ListenerProfile> profile;
  late final AuthSession expected;

  Widget get composer => ValueListenableBuilder<ListenerProfile>(
    valueListenable: profile,
    builder: (_, value, __) => ListenerOverthinkingDraftComposer(
      key: key,
      draft: OverthinkingProfileDraftArgs(
        postId: 'source',
        expectedSession: expected,
      ),
      profile: value,
      repository: shares,
      postsRepository: posts,
      sessions: sessions,
      onFinished: completed.add,
    ),
  );

  Future<void> mount(
    WidgetTester tester, {
    double width = 390,
    double scale = 1,
    bool settle = true,
    bool lazy = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: lazy
              ? ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: 40,
                  itemBuilder: (_, index) =>
                      index == 0 ? composer : const SizedBox(height: 250),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: composer,
                ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }
}
