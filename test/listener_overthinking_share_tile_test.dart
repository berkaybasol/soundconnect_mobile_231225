import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/data/models/overthinking_post_model.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_profile_share_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_overthinking_share_tile.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/presentation/screens/listener_profile_theme.dart';

import 'support/event_audience_fakes.dart';

void main() {
  late _Shares repository;
  late AudienceTestSessions sessions;
  late ValueNotifier<OverthinkingProfileShare> row;
  late ValueNotifier<bool> visible;
  late GlobalKey<NavigatorState> navigator;
  late List<String> removed;
  late List<String> opened;
  late List<String> errors;
  late int refreshes;
  late bool current;
  Future<void> Function(String)? onOpen;

  setUp(() {
    repository = _Shares();
    sessions = AudienceTestSessions(audienceSession(user: 'sharer'));
    row = ValueNotifier(_share());
    visible = ValueNotifier(true);
    navigator = GlobalKey<NavigatorState>();
    removed = [];
    opened = [];
    errors = [];
    refreshes = 0;
    current = true;
    onOpen = null;
  });

  tearDown(() {
    row.dispose();
    visible.dispose();
    sessions.dispose();
  });

  Future<void> mount(WidgetTester tester, {bool owner = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: ListenerProfileTheme(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<bool>(
                valueListenable: visible,
                builder: (_, show, _) => show
                    ? ValueListenableBuilder<OverthinkingProfileShare>(
                        valueListenable: row,
                        builder: (context, share, _) =>
                            ListenerOverthinkingShareTile(
                              share: share,
                              username: 'sharer',
                              ownerUserId: owner ? 'sharer' : null,
                              repository: repository,
                              sessions: sessions,
                              isCurrent: () => current,
                              onRefresh: () async => refreshes++,
                              onRemoved: removed.add,
                              onError: errors.add,
                              onOpenSource: (postId) async {
                                opened.add(postId);
                                await onOpen?.call(postId);
                              },
                            ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDelete(WidgetTester tester) async {
    await tester.tap(
      find.byKey(Key('listener-overthinking-remove-${row.value.shareId}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paylaşımı sil'));
    await tester.pumpAndSettle();
  }

  testWidgets('open resolves source and refreshes the authoritative parent', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.text('Devamını gör…'));
    await tester.pumpAndSettle();
    expect(opened, ['source-post']);
    expect(refreshes, 1);
    expect(repository.deleted, isEmpty);
  });

  testWidgets(
    'only confirmation deletes the exact share with captured session',
    (tester) async {
      await mount(tester);
      final expectedSession = sessions.session;
      await openDelete(tester);
      expect(repository.deleted, isEmpty);
      await tester.tap(
        find.byKey(const Key('listener-overthinking-remove-confirm')),
      );
      await tester.pumpAndSettle();
      expect(repository.deleted, ['publication']);
      expect(identical(repository.expectedSession, expectedSession), isTrue);
      expect(removed, ['publication']);
      expect(refreshes, 1);
    },
  );

  testWidgets('public viewer can open but has no deletion menu', (
    tester,
  ) async {
    await mount(tester, owner: false);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.text('Devamını gör…'));
    await tester.pumpAndSettle();
    expect(opened, ['source-post']);
  });

  testWidgets('mixed listener musician cannot remove an owned share', (
    tester,
  ) async {
    sessions.replace(
      audienceSession(
        user: 'sharer',
        roles: ['ROLE_LISTENER', 'ROLE_MUSICIAN'],
      ),
    );
    await mount(tester);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('cancel never mutates or refreshes', (tester) async {
    await mount(tester);
    await openDelete(tester);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(repository.deleted, isEmpty);
    expect(removed, isEmpty);
    expect(refreshes, 0);
  });

  testWidgets('a cached popup cannot remove a replacement row', (tester) async {
    await mount(tester);
    await tester.tap(
      find.byKey(const Key('listener-overthinking-remove-publication')),
    );
    await tester.pumpAndSettle();
    row.value = _share(title: 'Yeni görünüm');
    await tester.pump();
    await tester.tap(find.text('Paylaşımı sil'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('listener-share-delete-dialog')), findsNothing);
    expect(repository.deleted, isEmpty);
  });

  testWidgets(
    'replacement dismisses only its confirmation under a newer route',
    (tester) async {
      await mount(tester);
      await openDelete(tester);
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => const Scaffold(body: Text('Başka sayfa')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      row.value = _share(id: 'new-publication');
      await tester.pumpAndSettle();
      expect(find.text('Başka sayfa'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('listener-share-delete-dialog')),
        findsNothing,
      );
      expect(repository.deleted, isEmpty);
    },
  );

  testWidgets(
    'token change hides the old projection and dismisses its dialog',
    (tester) async {
      await mount(tester);
      await openDelete(tester);
      sessions.replace(audienceSession(user: 'sharer', token: 'renewed'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('listener-share-delete-dialog')),
        findsNothing,
      );
      expect(find.text('Yazı'), findsNothing);
      expect(repository.deleted, isEmpty);
      row.value = _share(title: 'Yeni oturumun yazısı');
      await tester.pumpAndSettle();
      expect(find.text('Yeni oturumun yazısı'), findsOneWidget);
    },
  );

  testWidgets('late source completion cannot refresh a replacement row', (
    tester,
  ) async {
    final pending = Completer<void>();
    onOpen = (_) => pending.future;
    await mount(tester);
    await tester.tap(find.text('Devamını gör…'));
    await tester.pump();
    row.value = _share(title: 'Yeni görünüm');
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(refreshes, 0);
    expect(opened, ['source-post']);
  });

  testWidgets('late deletion cannot remove a replacement publication', (
    tester,
  ) async {
    final pending = Completer<Result<void>>();
    repository.onDelete = () => pending.future;
    await mount(tester);
    await openDelete(tester);
    await tester.tap(
      find.byKey(const Key('listener-overthinking-remove-confirm')),
    );
    await tester.pumpAndSettle();
    expect(repository.deleted, ['publication']);
    row.value = _share(id: 'replacement');
    await tester.pump();
    pending.complete(const Result.success(null));
    await tester.pumpAndSettle();
    expect(removed, isEmpty);
    expect(refreshes, 0);
  });

  testWidgets('uncertain deletion preserves row and asks parent to reconcile', (
    tester,
  ) async {
    repository.onDelete = () async => throw StateError('Network interrupted');
    await mount(tester);
    await openDelete(tester);
    await tester.tap(
      find.byKey(const Key('listener-overthinking-remove-confirm')),
    );
    await tester.pumpAndSettle();
    expect(removed, isEmpty);
    expect(refreshes, 1);
    expect(
      find.text('Paylaşım kaldırılamadı. Yeniden deneyebilirsin.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('parent invalidation prevents retained open callbacks', (
    tester,
  ) async {
    await mount(tester);
    current = false;
    await tester.tap(find.text('Devamını gör…'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(refreshes, 0);
  });

  for (final stale in ['current', 'token', 'route']) {
    testWidgets(
      'disposed mutation reports only to its current parent: $stale',
      (tester) async {
        final pending = Completer<Result<void>>();
        repository.onDelete = () => pending.future;
        await mount(tester);
        await openDelete(tester);
        await tester.tap(
          find.byKey(const Key('listener-overthinking-remove-confirm')),
        );
        await tester.pumpAndSettle();
        visible.value = false;
        await tester.pumpAndSettle();
        if (stale == 'token') {
          sessions.replace(audienceSession(user: 'sharer', token: 'renewed'));
        }
        if (stale == 'route') {
          unawaited(
            navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('Başka sayfa')),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }
        pending.completeError(StateError('Connection lost'));
        await tester.pumpAndSettle();
        expect(errors, stale == 'current' ? hasLength(1) : isEmpty);
        expect(removed, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

OverthinkingProfileShare _share({
  String id = 'publication',
  String title = 'Yazı',
}) => OverthinkingProfileShare(
  shareId: id,
  note: null,
  publishedAt: DateTime.utc(2026, 9, 10, 18),
  post: OverthinkingPostModel.fromJson({
    'id': 'source-post',
    'title': title,
    'content': 'Bir yazının profil paylaşımı.',
    'anonymous': true,
    'visibilityType': 'ANONYMOUS',
    'canViewAuthor': false,
    'likeCount': 0,
    'commentCount': 0,
  }),
);

class _Shares extends Fake implements OverthinkingProfileShareRepository {
  final deleted = <String>[];
  AuthSession? expectedSession;
  Future<Result<void>> Function()? onDelete;

  @override
  Future<Result<void>> deleteShare({
    required String shareId,
    required AuthSession expectedSession,
  }) async {
    deleted.add(shareId);
    this.expectedSession = expectedSession;
    return onDelete?.call() ?? const Result.success(null);
  }
}
