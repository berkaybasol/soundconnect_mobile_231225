import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
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
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_user_profile_resolver.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/entities/dm_profile_target.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_item.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_like_state.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_user_summary.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/comment_thread_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_author_identity.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_thread_view.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/widgets/comment_like_button.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/media_detail_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/video_reel_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/cubit/overthinking_feed_state.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_feed_screen.dart';
import 'package:soundconnect_23_12_25codx/shared/images/app_cached_network_image.dart';
import 'package:soundconnect_23_12_25codx/shared/theme/app_theme.dart';
import 'package:soundconnect_23_12_25codx/shared/widgets/ghost_profile_badge.dart';

const _error = AppError(code: 'network', message: 'Yorum gönderilemedi.');

void main() {
  setUp(() async => serviceLocator.reset());
  tearDown(() async => serviceLocator.reset());

  for (final kind in ['photo', 'audio', 'video', 'reel', 'overthinking']) {
    testWidgets(
      'reference comments $kind like targets exact root and reply without eager reads',
      (tester) async {
        final repo = _Repository();
        await _mount(tester, repo, mediaKind: kind);
        if (kind == 'reel') {
          tester
              .widget<GestureDetector>(
                find
                    .ancestor(
                      of: find.byIcon(Icons.chat_bubble_outline),
                      matching: find.byType(GestureDetector),
                    )
                    .first,
              )
              .onTap!();
          await tester.pumpAndSettle();
        }
        expect(repo.likeReads, isEmpty);
        expect(repo.likeWrites, isEmpty);
        expect(repo.replyPages, isEmpty);
        final rootLike = find.byKey(const ValueKey('comment-like-root'));
        await _tap(tester, rootLike);
        expect(repo.likeWrites, [('root', true)]);
        await _tap(tester, find.byKey(const ValueKey('comment-replies-root')));
        expect(repo.replyPages, [0]);
        await _tap(
          tester,
          find.byKey(const ValueKey('comment-like-reply-first')),
        );
        expect(repo.likeWrites, [('root', true), ('reply-first', true)]);
        expect(repo.replyPages, [0]);
        expect(repo.likeReads, isEmpty);
        expect(
          find.byKey(const ValueKey('comment-reply-first')),
          findsOneWidget,
        );
        expect(find.byType(CommentLikeButton), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reference comments submitting to a folded thread does not load or open replies',
    (tester) async {
      final repo = _Repository();
      await _mount(tester, repo);
      final root = find.byKey(const ValueKey('comment-root'));
      await _tap(
        tester,
        find.descendant(of: root, matching: find.text('Yanıtla')),
      );
      await tester.enterText(find.byType(TextField), 'Yeni yanıt');
      await _tap(tester, find.byTooltip('Yorumu gönder'));
      expect(repo.creates, [('Yeni yanıt', 'root')]);
      expect(repo.replyPages, isEmpty);
      expect(find.text('Yanıtları gizle'), findsNothing);
      expect(find.text('Yanıtları göster (21)'), findsOneWidget);
    },
  );

  for (final failed in [false, true]) {
    testWidgets(
      'reference comments folding in-flight reply page remains folded on ${failed ? 'failure' : 'success'}',
      (tester) async {
        final pending = Completer<Result<CommentPage>>();
        final repo = _Repository()..pendingReplies = pending;
        await _mount(tester, repo);
        final toggle = find.byKey(const ValueKey('comment-replies-root'));
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pump();
        await tester.tap(toggle);
        await tester.pump();
        pending.complete(
          failed
              ? const Result.failure(_error)
              : Result.success(
                  CommentPage(
                    items: [
                      _comment('late', parent: 'root', text: 'Gecikmiş yanıt'),
                    ],
                    totalElements: 1,
                  ),
                ),
        );
        await tester.pumpAndSettle();
        expect(repo.replyPages, [0]);
        expect(find.text('Gecikmiş yanıt'), findsNothing);
        expect(find.text('Yanıtlar yüklenemedi · Tekrar dene'), findsNothing);
        expect(find.text('Yanıtları gizle'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reference comments confirmed folded reply preserves known count when refresh fails',
    (tester) async {
      final repo = _Repository()..failAfterCreate = true;
      await _mount(tester, repo);
      final root = find.byKey(const ValueKey('comment-root'));
      await _tap(
        tester,
        find.descendant(of: root, matching: find.text('Yanıtla')),
      );
      await tester.enterText(find.byType(TextField), 'Kaydedilen yanıt');
      await _tap(tester, find.byTooltip('Yorumu gönder'));
      expect(repo.creates, [('Kaydedilen yanıt', 'root')]);
      expect(repo.replyPages, isEmpty);
      expect(_input(tester), '');
      expect(find.text('Yanıtları göster (22)'), findsOneWidget);
      expect(find.text('Yanıtları gizle'), findsNothing);
      expect(
        find.text('İşlem tamamlandı. Yorum listesi yenilenemedi.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reference comments cached replies cannot survive root privacy reprojection',
    (tester) async {
      final repo = _Repository();
      await _mount(tester, repo);
      await _tap(tester, find.byKey(const ValueKey('comment-replies-root')));
      expect(find.text('İlk yanıt'), findsOneWidget);
      final oldLike = tester
          .widget<TextButton>(
            find.byKey(const ValueKey('comment-like-reply-first')),
          )
          .onPressed!;
      repo.roots = [_comment('root', anonymous: true, replies: 21)];
      await tester
          .element(find.byType(CommentThreadView))
          .read<CommentThreadCubit>()
          .load(targetType: 'MEDIA', targetId: 'media');
      await tester.pumpAndSettle();
      expect(find.text('İlk yanıt'), findsNothing);
      oldLike();
      await tester.pumpAndSettle();
      expect(repo.likeWrites, isEmpty);
      expect(repo.replyPages, [0]);
      expect(tester.takeException(), isNull);
    },
  );

  for (final error in const [
    AppError(
      code: '9356',
      message:
          'Bu içerikte art arda birkaç yorum gönderdin. 12 saniye bekleyip tekrar deneyebilirsin.',
      retryAfter: Duration(seconds: 12),
    ),
    AppError(
      code: '9357',
      message:
          'Yorum şu anda gönderilemiyor. Biraz sonra tekrar deneyebilirsin.',
      retryAfter: Duration(seconds: 5),
    ),
  ]) {
    for (final reply in [false, true]) {
      testWidgets(
        'comment anti-spam shared ${reply ? 'reply' : 'root'} ${error.code} preserves text and retries only explicitly',
        (tester) async {
          final pending = Completer<Result<CommentItem>>();
          final repo = _Repository()..pendingCreate = pending;
          var confirmed = 0;
          await _mount(tester, repo, onCreated: () => confirmed++);
          if (reply) await _tap(tester, find.text('Yanıtla'));
          const draft = 'Yorumum kaybolmasın 🎵';
          await tester.enterText(find.byType(TextField), draft);
          await tester.pump();
          await tester.tap(find.byTooltip('Yorumu gönder'));
          await tester.pump();
          final reads = repo.pages.length;
          pending.complete(Result.failure(error));
          await tester.pumpAndSettle();
          expect(_input(tester), draft);
          expect(find.text(error.message), findsOneWidget);
          expect(find.textContaining('Sonuç doğrulanamadı'), findsNothing);
          expect(find.textContaining('Gönderilmiş olabilir'), findsNothing);
          expect(confirmed, 0);
          expect(repo.pages.length, reads);
          if (reply) {
            expect(find.textContaining('Yanıtlanıyor:'), findsOneWidget);
          }
          await tester.pump(const Duration(seconds: 31));
          await tester.pumpAndSettle();
          expect(repo.creates, hasLength(1));
          expect(_input(tester), draft);

          repo.pendingCreate = null;
          final retry = tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Yorumu gönder',
                ),
              )
              .onPressed!;
          retry();
          retry();
          await tester.pumpAndSettle();
          expect(repo.creates, [
            (draft, reply ? 'root' : null),
            (draft, reply ? 'root' : null),
          ]);
          expect(_input(tester), '');
          expect(confirmed, 1);
          expect(find.text(error.message), findsNothing);
          expect(find.textContaining('Yanıtlanıyor:'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'comment anti-spam shared first three sends have no artificial client wait',
    (tester) async {
      final repo = _Repository();
      var confirmed = 0;
      await _mount(tester, repo, onCreated: () => confirmed++);
      for (var index = 0; index < 3; index++) {
        await tester.enterText(find.byType(TextField), 'Ardışık yorum $index');
        await _tap(tester, find.byTooltip('Yorumu gönder'));
        expect(_input(tester), '');
        expect(repo.creates, hasLength(index + 1));
      }
      expect(confirmed, 3);
    },
  );

  testWidgets(
    'comment anti-spam shared account replacement clears rejected draft and forbids retained retry',
    (tester) async {
      final sessions = _Sessions();
      final pending = Completer<Result<CommentItem>>();
      final repo = _Repository()..pendingCreate = pending;
      await _mount(tester, repo, sessions: sessions);
      await tester.enterText(find.byType(TextField), 'Önceki hesabın yorumu');
      await tester.pump();
      await tester.tap(find.byTooltip('Yorumu gönder'));
      await tester.pump();
      pending.complete(
        const Result.failure(
          AppError(
            code: '9356',
            message: 'Biraz bekleyip tekrar deneyebilirsin.',
            retryAfter: Duration(seconds: 12),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final retry = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Yorumu gönder',
            ),
          )
          .onPressed!;
      sessions.replace(_session('new-viewer'));
      await tester.pumpAndSettle();
      retry();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(_input(tester), '');
      expect(repo.creates, hasLength(1));
      expect(find.text('Biraz bekleyip tekrar deneyebilirsin.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed initial list is not an empty success and supports retry',
    (tester) async {
      final repo = _Repository()..failRead = true;
      await _mount(tester, repo);
      expect(find.text('Henüz yorum yok. İlk yorumu sen yaz.'), findsNothing);
      expect(find.text('Yorum gönderilemedi.'), findsOneWidget);
      repo.failRead = false;
      await _tap(tester, find.text('Yorumları yeniden yükle'));
      expect(find.text('Birlikte dinleyelim.'), findsOneWidget);
    },
  );

  testWidgets('root pages load explicitly, never eagerly request replies', (
    tester,
  ) async {
    final repo = _Repository()..total = 51;
    await _mount(tester, repo);
    expect(repo.pages, [0]);
    expect(repo.replyPages, isEmpty);
    await _tap(tester, find.text('Daha fazla yorum'));
    expect(repo.pages, [0, 1]);
    expect(find.text('Son yorum'), findsOneWidget);
    expect(find.text('Daha fazla yorum'), findsNothing);
  });

  testWidgets(
    'failed submission retains draft and successful retry clears once',
    (tester) async {
      final repo = _Repository()..failCreate = true;
      var created = 0;
      await _mount(tester, repo, onCreated: () => created++);
      await tester.enterText(find.byType(TextField), 'Metnim kaybolmasın');
      await _tap(tester, find.byTooltip('Yorumu gönder'));
      expect(_input(tester), 'Metnim kaybolmasın');
      expect(created, 0);
      repo.failCreate = false;
      await _tap(tester, find.byTooltip('Yorumu gönder'));
      expect(_input(tester), '');
      expect(created, 1);
      expect(repo.creates.length, 2);
    },
  );

  testWidgets(
    'confirmed write with failed list refresh clears text and does not replay',
    (tester) async {
      final repo = _Repository()..failAfterCreate = true;
      var created = 0;
      await _mount(tester, repo, onCreated: () => created++);
      await tester.enterText(find.byType(TextField), 'Gönderildi');
      await _tap(tester, find.byTooltip('Yorumu gönder'));
      expect(_input(tester), '');
      expect(created, 1);
      expect(
        find.text('İşlem tamamlandı. Yorum listesi yenilenemedi.'),
        findsOneWidget,
      );
      repo.failRead = false;
      await _tap(tester, find.text('Yorumları yeniden yükle'));
      expect(repo.creates.length, 1);
    },
  );

  testWidgets('pending send locks field and suppresses duplicate taps', (
    tester,
  ) async {
    final pending = Completer<Result<CommentItem>>();
    final repo = _Repository()..pendingCreate = pending;
    await _mount(tester, repo);
    await tester.enterText(find.byType(TextField), 'Tek yorum');
    await tester.tap(find.byTooltip('Yorumu gönder'));
    await tester.pump();
    await tester.tap(find.byTooltip('Yorumu gönder'));
    await tester.pump();
    expect(repo.creates.length, 1);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    pending.complete(Result.success(_comment('created')));
    await tester.pumpAndSettle();
    expect(_input(tester), '');
  });

  testWidgets(
    'logout clears draft and late create cannot increment or reveal old identity',
    (tester) async {
      final sessions = _Sessions();
      final pending = Completer<Result<CommentItem>>();
      final repo = _Repository()..pendingCreate = pending;
      var created = 0;
      await _mount(
        tester,
        repo,
        sessions: sessions,
        onCreated: () => created++,
      );
      await tester.enterText(find.byType(TextField), 'Özel taslak');
      await tester.tap(find.byTooltip('Yorumu gönder'));
      await tester.pump();
      sessions.replace(const AuthSession.guest());
      await tester.pump();
      pending.complete(Result.success(_comment('old')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('@aedrum'), findsNothing);
      expect(find.text('Giriş yap'), findsOneWidget);
      expect(created, 0);
    },
  );

  testWidgets('late create after thread disposal is harmless', (tester) async {
    final pending = Completer<Result<CommentItem>>();
    final repo = _Repository()..pendingCreate = pending;
    await _mount(tester, repo);
    await tester.enterText(find.byType(TextField), 'Metin');
    await tester.tap(find.byTooltip('Yorumu gönder'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(Result.success(_comment('created')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reply pages expand lazily, retry and collapse without losing fetched rows',
    (tester) async {
      final repo = _Repository()..failReplies = true;
      await _mount(tester, repo);
      await _tap(tester, find.text('Yanıtları göster (21)'));
      expect(repo.replyPages, [0]);
      expect(find.text('Yanıtlar yüklenemedi · Tekrar dene'), findsOneWidget);
      repo.failReplies = false;
      await _tap(tester, find.text('Yanıtlar yüklenemedi · Tekrar dene'));
      expect(find.text('İlk yanıt'), findsOneWidget);
      await _tap(tester, find.text('Daha fazla yanıt'));
      expect(repo.replyPages, [0, 0, 1]);
      expect(find.text('Son yanıt'), findsOneWidget);
      await _tap(tester, find.text('Yanıtları gizle'));
      expect(find.text('İlk yanıt'), findsNothing);
      await _tap(tester, find.text('Yanıtları göster (21)'));
      expect(repo.replyPages.length, 3);
      expect(find.text('Son yanıt'), findsOneWidget);
    },
  );

  testWidgets('reply-to-reply submits root parent and shows confirmed reply', (
    tester,
  ) async {
    final repo = _Repository();
    await _mount(tester, repo);
    await _tap(tester, find.text('Yanıtları göster (21)'));
    final replyRow = find.byKey(const ValueKey('comment-reply-first'));
    await _tap(
      tester,
      find.descendant(of: replyRow, matching: find.text('Yanıtla')),
    );
    await tester.enterText(find.byType(TextField), 'Yanıtım');
    await _tap(tester, find.byTooltip('Yorumu gönder'));
    expect(repo.creates.single, ('Yanıtım', 'root'));
    expect(repo.replyPages, [0, 0]);
    expect(find.textContaining('Yanıtlanıyor:'), findsNothing);
  });

  testWidgets('session change discards late reply page and reply target', (
    tester,
  ) async {
    final sessions = _Sessions();
    final pending = Completer<Result<CommentPage>>();
    final repo = _Repository()..pendingReplies = pending;
    await _mount(tester, repo, sessions: sessions);
    await tester.tap(find.text('Yanıtları göster (21)'));
    await tester.pump();
    sessions.replace(_session('second'));
    await tester.pump();
    pending.complete(
      Result.success(
        CommentPage(
          items: [_comment('secret-reply', text: 'Eski özel yanıt')],
          totalElements: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Eski özel yanıt'), findsNothing);
    expect(find.textContaining('Yanıtlanıyor:'), findsNothing);
  });

  testWidgets('delete only own author, cancellation sends no write', (
    tester,
  ) async {
    final repo = _Repository()
      ..roots = [_comment('mine', userId: 'viewer'), _comment('other')];
    await _mount(tester, repo);
    expect(find.byTooltip('Yorumu sil'), findsOneWidget);
    await _tap(tester, find.byTooltip('Yorumu sil'));
    expect(find.text('Yorumu silmek istiyor musun?'), findsOneWidget);
    await _tap(tester, find.text('Vazgeç'));
    expect(repo.deletes, isEmpty);
    await _tap(tester, find.byTooltip('Yorumu sil'));
    await _tap(
      tester,
      find.descendant(of: find.byType(AlertDialog), matching: find.text('Sil')),
    );
    expect(repo.deletes, ['mine']);
  });

  testWidgets(
    'account switch closes deletion dialog and stale confirmation cannot write',
    (tester) async {
      final sessions = _Sessions();
      final repo = _Repository()..roots = [_comment('mine', userId: 'viewer')];
      await _mount(tester, repo, sessions: sessions);
      await _tap(tester, find.byTooltip('Yorumu sil'));
      sessions.replace(_session('second'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.deletes, isEmpty);
    },
  );

  testWidgets(
    'anonymous/deleted never request supplied image or expose username or link',
    (tester) async {
      final repo = _Repository()
        ..roots = [
          _comment(
            'anon',
            anonymous: true,
            avatar: 'https://secret.invalid/avatar',
            username: 'secret',
          ),
          _comment(
            'deleted',
            deleted: true,
            avatar: 'https://secret.invalid/deleted',
            username: 'secret2',
          ),
        ];
      await _mount(tester, repo);
      expect(find.byType(AppCachedNetworkImage), findsNothing);
      expect(find.text('@secret'), findsNothing);
      expect(find.text('@secret2'), findsNothing);
      expect(find.text('Kimliğini açıklamak istemeyen yazar'), findsOneWidget);
      expect(find.text('Silinen yorum'), findsOneWidget);
      expect(find.byTooltip('Yorumu sil'), findsNothing);
    },
  );

  testWidgets('visible ghost keeps badge, avatar and a limited-profile link', (
    tester,
  ) async {
    final repo = _Repository()
      ..roots = [
        _comment('ghost', ghost: true, avatar: 'https://image.invalid/avatar'),
      ];
    await _mount(tester, repo, settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(GhostProfileBadge), findsOneWidget);
    expect(find.byType(AppCachedNetworkImage), findsOneWidget);
    final avatar = tester.widget<CommentAuthorAvatar>(
      find.byType(CommentAuthorAvatar),
    );
    expect(avatar.onTap, isNotNull);
  });

  for (final role in ['LISTENER', 'MUSICIAN', 'VENUE', 'STUDIO']) {
    testWidgets(
      '$role own comment opens owner route without a public resolver call',
      (tester) async {
        final sessions = _Sessions()..replace(_session('viewer', role: role));
        final repo = _Repository()
          ..roots = [_comment('mine', userId: 'viewer')];
        final routes = <String>[];
        await _mount(tester, repo, sessions: sessions, routes: routes);
        await _tap(tester, find.text('@aedrum'));
        expect(routes, [
          switch (role) {
            'LISTENER' => AppRoutes.listenerProfile,
            'MUSICIAN' => AppRoutes.musicianProfile,
            'VENUE' => AppRoutes.venueProfile,
            _ => AppRoutes.studioProfile,
          },
        ]);
      },
    );
  }

  testWidgets(
    'other author resolves stable ID on tap only and duplicate taps do not duplicate routes',
    (tester) async {
      final resolver = _Resolver();
      final repo = _Repository();
      final routes = <String>[];
      serviceLocator.registerSingleton<DmUserProfileResolver>(resolver);
      await _mount(tester, repo, routes: routes);
      expect(resolver.calls, isEmpty);
      await tester.tap(find.text('@aedrum'));
      await tester.tap(find.text('@aedrum'));
      await tester.pump();
      expect(resolver.calls, ['other']);
      resolver.pending.complete([_target]);
      await tester.pumpAndSettle();
      expect(routes, [AppRoutes.musicianPublicProfile]);
    },
  );

  testWidgets('late profile resolver after session switch cannot navigate', (
    tester,
  ) async {
    final sessions = _Sessions();
    final resolver = _Resolver();
    final routes = <String>[];
    serviceLocator.registerSingleton<DmUserProfileResolver>(resolver);
    await _mount(tester, _Repository(), sessions: sessions, routes: routes);
    await tester.tap(find.text('@aedrum'));
    await tester.pump();
    sessions.replace(_session('second'));
    await tester.pump();
    resolver.pending.complete([_target]);
    await tester.pumpAndSettle();
    expect(routes, isEmpty);
  });

  testWidgets(
    'draft input rejects more than500UTF16 units and normalizes CRLF',
    (tester) async {
      await _mount(tester, _Repository());
      await tester.enterText(find.byType(TextField), 'satır1\r\nsatır2');
      expect(_input(tester), 'satır1\nsatır2');
      await tester.enterText(find.byType(TextField), 'a' * 501);
      expect(_input(tester).length, lessThanOrEqualTo(500));
      await tester.enterText(find.byType(TextField), '🎵' * 251);
      expect(_input(tester).length, lessThanOrEqualTo(500));
    },
  );

  testWidgets(
    'narrow screen 2x text handles long names multiline comments and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository()
        ..roots = [
          _comment(
            'long',
            username: 'ÇokUzunBirKullanıcıAdı' * 5,
            text: 'Uzun bir yorum.\n' * 8,
          ),
        ];
      await _mount(tester, repo, sheet: true, scale: 2);
      await tester.tap(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final kind in ['photo', 'audio', 'video']) {
    testWidgets(
      'real $kind MediaDetailScreen mounts shared comments and retains failed send',
      (tester) async {
        final repo = _Repository()..failCreate = true;
        await _mount(tester, repo, mediaKind: kind);
        expect(find.byType(CommentThreadView), findsOneWidget);
        await tester.ensureVisible(find.byType(TextField));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Medya yorumum');
        await _tap(tester, find.byTooltip('Yorumu gönder'));
        expect(_input(tester), 'Medya yorumum');
        expect(repo.creates.single.$1, 'Medya yorumum');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'real reel comments open once without waiting for network and safely dismiss pending send',
    (tester) async {
      final repo = _Repository();
      await _mount(tester, repo, mediaKind: 'reel');
      final readsBeforeOpening = repo.pages.length;
      final open = tester
          .widget<GestureDetector>(
            find
                .ancestor(
                  of: find.byIcon(Icons.chat_bubble_outline),
                  matching: find.byType(GestureDetector),
                )
                .first,
          )
          .onTap!;
      open();
      open();
      await tester.pumpAndSettle();
      expect(find.byType(CommentThreadSheet), findsOneWidget);
      expect(repo.pages.length, readsBeforeOpening + 1);
      final pending = Completer<Result<CommentItem>>();
      repo.pendingCreate = pending;
      await tester.enterText(find.byType(TextField), 'Video yorumu');
      await tester.tap(find.byTooltip('Yorumu gönder'));
      await tester.pump();
      final sheetContext = tester.element(find.byType(CommentThreadSheet));
      Navigator.of(sheetContext).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      pending.complete(Result.success(_comment('created')));
      await tester.pumpAndSettle();
      expect(find.byType(CommentThreadSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real Overthinking detail uses same error-aware thread without changing post body',
    (tester) async {
      final repo = _Repository()..failCreate = true;
      await _mount(tester, repo, mediaKind: 'overthinking');
      expect(find.text('Düşünce başlığı'), findsOneWidget);
      expect(find.byType(CommentThreadView), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Düşünceye yorum');
      await _tap(tester, find.byTooltip('Yorumu gönder'));
      expect(_input(tester), 'Düşünceye yorum');
      expect(repo.creates.single.$1, 'Düşünceye yorum');
    },
  );

  testWidgets(
    'silent session replacement blocks retained send and reply callbacks',
    (tester) async {
      final sessions = _Sessions();
      final repo = _Repository();
      await _mount(tester, repo, sessions: sessions);
      await tester.enterText(find.byType(TextField), 'Eski hesabın taslağı');
      await tester.pump();
      final send = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Yorumu gönder',
            ),
          )
          .onPressed!;
      final reply = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Yanıtları göster (21)'),
          )
          .onPressed!;
      sessions.replaceSilently(_session('second'));
      send();
      reply();
      await tester.pump();
      expect(repo.creates, isEmpty);
      expect(repo.replyPages, isEmpty);
    },
  );

  testWidgets(
    'stale root projection cannot fetch replies or resolve the old author',
    (tester) async {
      final repo = _Repository();
      final resolver = _Resolver();
      serviceLocator.registerSingleton<DmUserProfileResolver>(resolver);
      await _mount(tester, repo);
      final reply = tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Yanıtları göster (21)'),
          )
          .onPressed!;
      final author = tester
          .widget<CommentAuthorAvatar>(find.byType(CommentAuthorAvatar))
          .onTap!;
      repo.roots = [_comment('root', anonymous: true, replies: 21)];
      await tester
          .element(find.byType(CommentThreadView))
          .read<CommentThreadCubit>()
          .load(targetType: 'MEDIA', targetId: 'media');
      await tester.pumpAndSettle();
      reply();
      author();
      await tester.pump();
      expect(repo.replyPages, isEmpty);
      expect(resolver.calls, isEmpty);
    },
  );

  testWidgets(
    'root projection replaced while replies load discards stale identity rows',
    (tester) async {
      final pending = Completer<Result<CommentPage>>();
      final repo = _Repository()..pendingReplies = pending;
      await _mount(tester, repo);
      await tester.tap(find.text('Yanıtları göster (21)'));
      await tester.pump();
      repo.roots = [_comment('root', anonymous: true, replies: 21)];
      await tester
          .element(find.byType(CommentThreadView))
          .read<CommentThreadCubit>()
          .load(targetType: 'MEDIA', targetId: 'media');
      await tester.pump();
      pending.complete(
        Result.success(
          CommentPage(
            items: [_comment('old', text: 'Eski kimlik')],
            totalElements: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Eski kimlik'), findsNothing);
    },
  );

  testWidgets(
    'delete confirmation cannot act on a replaced author projection',
    (tester) async {
      final repo = _Repository()..roots = [_comment('mine', userId: 'viewer')];
      await _mount(tester, repo);
      await _tap(tester, find.byTooltip('Yorumu sil'));
      repo.roots = [_comment('mine', anonymous: true)];
      await tester
          .element(find.byType(CommentThreadView))
          .read<CommentThreadCubit>()
          .load(targetType: 'MEDIA', targetId: 'media');
      await tester.pumpAndSettle();
      await _tap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sil'),
        ),
      );
      expect(repo.deletes, isEmpty);
    },
  );

  if (Platform.environment['COMMENT_RENDER_DIR'] case final String directory) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'render reference shared comment cards folded and open at${scale}x with real fonts',
        (tester) async {
          await tester.runAsync(() async {
            final fonts =
                '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts';
            final loader = FontLoader('Roboto');
            for (final name in ['regular', 'medium', 'bold', 'black']) {
              loader.addFont(
                Future.value(
                  ByteData.sublistView(
                    await File('$fonts/Roboto-$name.ttf').readAsBytes(),
                  ),
                ),
              );
            }
            await loader.load();
            await (FontLoader('MaterialIcons')
                  ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
                .load();
          });
          tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repo = _Repository()
            ..roots = [
              _comment(
                'root',
                userId: 'viewer',
                username: 'bugrasahin',
                text: 'Sesler çok iyi olmuş!',
                replies: 2,
                likeCount: 12,
                likedByMe: true,
              ),
              _comment(
                'ghost',
                username: 'aedrum',
                ghost: true,
                text: 'Buradaki davul tonu çok güzel.',
                likeCount: 3,
              ),
              _comment(
                'anonymous',
                anonymous: true,
                text: 'Bu parçayı yeniden dinleyeceğim.',
              ),
            ]
            ..previewReplies = [
              _comment(
                'reply-first',
                userId: 'viewer',
                username: 'bugrasahin',
                parent: 'root',
                text: 'Teşekkürler.',
                likeCount: 2,
              ),
              _comment(
                'reply-second',
                username: 'aedrum',
                parent: 'root',
                text: 'Yeni kaydı bekliyoruz.',
                ghost: true,
                likeCount: 1,
                likedByMe: true,
              ),
            ];
          await _mount(tester, repo, sheet: true, scale: scale);
          for (final expanded in [false, true]) {
            if (expanded) {
              await _tap(
                tester,
                find.byKey(const ValueKey('comment-replies-root')),
              );
              if (scale == 2) {
                await tester.ensureVisible(
                  find.byKey(const ValueKey('comment-reply-first')),
                );
                await tester.pumpAndSettle();
              }
            }
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('comment-render')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await Directory(directory).create(recursive: true);
              await File(
                '$directory/shared-reference-${expanded ? 'open' : 'folded'}-${scale.toInt()}x.png',
              ).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            });
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Repository repo, {
  _Sessions? sessions,
  VoidCallback? onCreated,
  List<String>? routes,
  bool sheet = false,
  double scale = 1,
  String? mediaKind,
  bool settle = true,
}) async {
  sessions ??= _Sessions();
  serviceLocator.registerSingleton<AuthSessionManager>(sessions);
  serviceLocator.registerSingleton<EngagementRepository>(repo);
  final cubit = CommentThreadCubit(repo, sessions: sessions);
  final stats = InteractionStatsCubit(repo);
  addTearDown(cubit.close);
  addTearDown(stats.close);
  if (mediaKind != null) {
    serviceLocator.registerSingleton<AudioHandler>(BaseAudioHandler());
  }
  final thread = CommentThreadView(
    targetType: 'MEDIA',
    targetId: 'media',
    scrollable: sheet,
    onCommentCreated: onCreated,
  );
  final overthinking = mediaKind == 'overthinking' ? _FeedCubit() : null;
  if (overthinking != null) {
    addTearDown(overthinking.close);
    await cubit.load(targetType: 'OVERTHINKING', targetId: 'post');
  }
  final content = overthinking != null
      ? BlocProvider<OverthinkingFeedCubit>.value(
          value: overthinking,
          child: const OverthinkingDetailScreen(
            post: _post,
            revealRequesting: false,
          ),
        )
      : mediaKind == 'reel'
      ? const VideoReelScreen(
          title: 'Video',
          playbackUrl: '',
          thumbnailUrl: null,
          targetType: 'MEDIA',
          targetId: 'media',
          initialLikeCount: 0,
          initialCommentCount: 0,
        )
      : mediaKind != null
      ? MediaDetailScreen(
          title: 'Canlı kayıt',
          isVideo: mediaKind == 'video',
          isImage: mediaKind == 'photo',
          targetType: 'MEDIA',
          targetId: 'media',
          likeCount: 0,
          commentCount: 0,
        )
      : Scaffold(
          appBar: AppBar(title: const Text('Yorumlar')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: sheet ? thread : SingleChildScrollView(child: thread),
          ),
        );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.navy.copyWith(
        textTheme: AppTheme.navy.textTheme.apply(fontFamily: 'Roboto'),
      ),
      builder: (context, child) => RepaintBoundary(
        key: const Key('comment-render'),
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
      onGenerateRoute: (settings) {
        routes?.add(settings.name!);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) =>
              Scaffold(appBar: AppBar(), body: const Text('Profil')),
        );
      },
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(value: stats),
        ],
        child: content,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

String _input(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;
Future<void> _tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

AuthSession _session(String id, {String role = 'LISTENER'}) =>
    AuthSession.authenticated(
      token: 'token-$id',
      userId: id,
      username: id,
      accountStatus: 'ACTIVE',
      roles: [role],
      permissions: const [],
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      isAdmin: false,
    );

class _Sessions extends ChangeNotifier implements AuthSessionManager {
  AuthSession _value = _session('viewer');
  @override
  AuthSession get session => _value;
  void replaceSilently(AuthSession value) {
    _value = value;
  }

  void replace(AuthSession value) {
    _value = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CommentItem _comment(
  String id, {
  String userId = 'other',
  String username = 'aedrum',
  String text = 'Birlikte dinleyelim.',
  String? avatar,
  bool anonymous = false,
  bool deleted = false,
  bool ghost = false,
  int replies = 0,
  String? parent,
  int likeCount = 0,
  bool likedByMe = false,
}) => CommentItem(
  id: id,
  user: CommentUserSummary(
    id: userId,
    username: username,
    avatarUrl: avatar,
    visibilityMode: ghost
        ? ListenerVisibilityMode.ghost
        : ListenerVisibilityMode.standard,
  ),
  text: text,
  anonymousAuthor: anonymous,
  deleted: deleted,
  parentCommentId: parent,
  replyCount: replies,
  likeCount: likeCount,
  likedByMe: likedByMe,
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

class _Repository extends Fake implements EngagementRepository {
  List<CommentItem> roots = [_comment('root', replies: 21)];
  int total = 1;
  bool failRead = false,
      failCreate = false,
      failAfterCreate = false,
      failReplies = false;
  Completer<Result<CommentItem>>? pendingCreate;
  Completer<Result<CommentPage>>? pendingReplies;
  final pages = <int>[];
  final replyPages = <int>[];
  final creates = <(String, String?)>[];
  final deletes = <String>[];
  final likeReads = <String>[];
  final likeWrites = <(String, bool)>[];
  List<CommentItem>? previewReplies;
  @override
  Future<Result<CommentLikeState>> setCommentLike({
    required String commentId,
    required bool liked,
  }) async {
    likeWrites.add((commentId, liked));
    return Result.success(
      CommentLikeState(likeCount: liked ? 1 : 0, likedByMe: liked),
    );
  }

  @override
  Future<Result<CommentLikeState>> readCommentLike({
    required String commentId,
  }) async {
    likeReads.add(commentId);
    return const Result.success(
      CommentLikeState(likeCount: 0, likedByMe: false),
    );
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    pages.add(page);
    if (failRead) return const Result.failure(_error);
    return Result.success(
      CommentPage(
        items: page == 0 ? roots : [_comment('last', text: 'Son yorum')],
        totalElements: total,
        page: page,
        size: size,
      ),
    );
  }

  @override
  Future<Result<CommentPage>> listReplyPage(
    String commentId, {
    String? eventId,
    int page = 0,
    int size = 20,
  }) async {
    replyPages.add(page);
    if (pendingReplies != null) return pendingReplies!.future;
    if (failReplies) return const Result.failure(_error);
    if (previewReplies != null) {
      return Result.success(
        CommentPage(
          items: previewReplies!,
          totalElements: previewReplies!.length,
          page: page,
          size: size,
        ),
      );
    }
    return Result.success(
      CommentPage(
        items: [
          _comment(
            page == 0 ? 'reply-first' : 'reply-last',
            parent: commentId,
            text: page == 0 ? 'İlk yanıt' : 'Son yanıt',
          ),
        ],
        totalElements: 21,
        page: page,
        size: size,
      ),
    );
  }

  @override
  Future<Result<CommentItem>> createComment({
    required String targetType,
    required String targetId,
    required String text,
    String? parentCommentId,
  }) async {
    creates.add((text, parentCommentId));
    if (pendingCreate != null) return pendingCreate!.future;
    if (failCreate) return const Result.failure(_error);
    if (failAfterCreate) failRead = true;
    return Result.success(
      _comment(
        'created',
        text: text,
        userId: 'viewer',
        parent: parentCommentId,
      ),
    );
  }

  @override
  Future<Result<void>> deleteComment({required String commentId}) async {
    deletes.add(commentId);
    return const Result.success(null);
  }

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) async => const Result.success(0);
  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async => const Result.success(false);
}

const _target = DmProfileTarget(
  type: DmProfileTargetType.musician,
  id: 'profile-id',
  displayName: 'aedrum',
  imageUrl: null,
);

class _Resolver extends Fake implements DmUserProfileResolver {
  final calls = <String>[];
  final pending = Completer<List<DmProfileTarget>>();
  @override
  Future<List<DmProfileTarget>> resolveByUserId({
    required String userId,
    String? usernameHint,
  }) {
    calls.add(userId);
    return pending.future;
  }
}

const _post = OverthinkingPost(
  id: 'post',
  authorId: 'author',
  authorUsername: 'yazar',
  authorAvatarUrl: null,
  anonymous: false,
  canViewAuthor: true,
  visibilityType: 'PUBLIC',
  title: 'Düşünce başlığı',
  content: 'Düşünce metni',
  spotifyTrackUrl: null,
  spotifyArtistId: null,
  spotifyTrackName: null,
  spotifyArtistName: null,
  spotifyAlbumImageUrl: null,
  musicianTrackId: null,
  bandTrackId: null,
  artistId: null,
  artistType: null,
  likeCount: 0,
  commentCount: 1,
  likedByMe: false,
);

class _FeedCubit extends Cubit<OverthinkingFeedState>
    implements OverthinkingFeedCubit {
  _FeedCubit() : super(const OverthinkingFeedState.initial());
  @override
  void incrementCommentCount(String postId) {}
  @override
  Future<void> refreshPost(String postId) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
