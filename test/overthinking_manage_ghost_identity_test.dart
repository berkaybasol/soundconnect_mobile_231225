import 'package:flutter/material.dart' hide Page;
import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/token_store.dart';
import 'package:soundconnect_23_12_25codx/core/di/service_locator.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/core/pagination/page.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/domain/dm_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/dm/presentation/cubit/dm_badge_cubit.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_post.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/entities/overthinking_reveal_request.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/domain/overthinking_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/overthinking/presentation/screens/overthinking_manage_screen.dart';
import 'package:soundconnect_23_12_25codx/modules/profile/domain/entities/listener_visibility_mode.dart';

void main() {
  late DmBadgeCubit badgeCubit;

  setUp(() async {
    await serviceLocator.reset();
    badgeCubit = DmBadgeCubit(_NoopDmRepository(), _EmptyTokenStore());
    serviceLocator
      ..registerSingleton<OverthinkingRepository>(
        _RevealRequestRepositoryFake(),
      )
      ..registerSingleton<DmBadgeCubit>(badgeCubit);
  });

  tearDown(() async {
    await badgeCubit.close();
    await serviceLocator.reset();
  });

  testWidgets('incoming reveal request renders contextual ghost identity', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: OverthinkingManageScreen(initialTabIndex: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('@ghost_listener'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('reveal-requester-ghost-request-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('reveal-requester-avatar-request-1')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Hayalet profil'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _RevealRequestRepositoryFake implements OverthinkingRepository {
  static const _emptyPosts = Page<OverthinkingPost>(
    items: <OverthinkingPost>[],
    hasNext: false,
  );
  static const _emptyRequests = Page<OverthinkingRevealRequest>(
    items: <OverthinkingRevealRequest>[],
    hasNext: false,
  );

  @override
  Future<Result<Page<OverthinkingPost>>> getMyPosts({
    int page = 0,
    int size = 20,
  }) async => const Result.success(_emptyPosts);

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getIncomingRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(
    Page<OverthinkingRevealRequest>(
      items: <OverthinkingRevealRequest>[
        OverthinkingRevealRequest(
          id: 'request-1',
          postId: 'post-1',
          postTitle: 'Gece düşüncesi',
          requesterId: 'listener-1',
          requesterUsername: 'ghost_listener',
          requesterAvatarUrl: null,
          requesterVisibilityMode: ListenerVisibilityMode.ghost,
          authorId: 'author-1',
          status: 'PENDING',
          createdAt: null,
        ),
      ],
      hasNext: false,
    ),
  );

  @override
  Future<Result<Page<OverthinkingRevealRequest>>> getSentRevealRequests({
    int page = 0,
    int size = 20,
  }) async => const Result.success(_emptyRequests);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}

class _EmptyTokenStore implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> readToken() async => null;

  @override
  Future<void> writeToken(String token) async {}
}

class _NoopDmRepository implements DmRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError(invocation.memberName.toString());
}
