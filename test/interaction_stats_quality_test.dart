import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/auth/auth_session.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/data/engagement_repository_impl.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/entities/comment_page.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/presentation/cubit/interaction_stats_cubit.dart';

import 'support/event_audience_fakes.dart';
import 'support/recording_api_client.dart';

const _error = AppError(code: 'network', message: 'Offline');

enum _Operation { like, unlike, count, state }

void main() {
  for (final operation in _Operation.values) {
    test(
      '$operation content likes preserve encoded paths and transport session identity',
      () async {
        final sessions = AudienceTestSessions(audienceSession());
        addTearDown(sessions.dispose);
        final api = RecordingApiClient((_) => _payload(operation));
        final repository = EngagementRepositoryImpl(api, sessions: sessions);
        expect(
          (await _request(repository, operation, 'asset/ç?x=1')).isSuccess,
          isTrue,
        );
        expect(
          api.lastRequest.path,
          startsWith('/api/v1/likes/MEDIA/asset%2F%C3%A7%3Fx%3D1'),
        );
        expect(api.lastRequest.requestContext?.expectedSessionKey, 'listener');
        expect(api.lastRequest.method, switch (operation) {
          _Operation.like => RecordedHttpMethod.post,
          _Operation.unlike => RecordedHttpMethod.delete,
          _ => RecordedHttpMethod.get,
        });
      },
    );

    test(
      '$operation cannot dispatch from a guest or an ineligible account',
      () async {
        for (final session in [
          const AuthSession.guest(),
          audienceSession(status: 'INACTIVE'),
        ]) {
          final sessions = AudienceTestSessions(session);
          addTearDown(sessions.dispose);
          final api = RecordingApiClient((_) => _payload(operation));
          expect(
            (await _request(
              EngagementRepositoryImpl(api, sessions: sessions),
              operation,
            )).isSuccess,
            isFalse,
          );
          expect(api.requests, isEmpty);
        }
      },
    );

    test(
      '$operation drops old account response after account switch',
      () async {
        final sessions = AudienceTestSessions(audienceSession());
        addTearDown(sessions.dispose);
        final response = Completer<Object?>();
        final api = RecordingApiClient((_) => response.future);
        final pending = _request(
          EngagementRepositoryImpl(api, sessions: sessions),
          operation,
        );
        sessions.replace(audienceSession(user: 'other', token: 'other-token'));
        response.complete(_payload(operation));
        expect(
          (await pending).error?.code,
          'engagement_comment_session_changed',
        );
      },
    );
  }

  test(
    'content counts and personal like state reject malformed successful payloads',
    () async {
      for (final raw in [null, -1, 1.5, '3', 9007199254740992]) {
        final repository = EngagementRepositoryImpl(
          RecordingApiClient((_) => raw),
        );
        expect(
          (await repository.getLikeCount(
            targetType: 'MEDIA',
            targetId: 'asset',
          )).isSuccess,
          isFalse,
        );
      }
      for (final raw in [null, 0, 'false', <String, Object>{}]) {
        final repository = EngagementRepositoryImpl(
          RecordingApiClient((_) => raw),
        );
        expect(
          (await repository.isLiked(
            targetType: 'MEDIA',
            targetId: 'asset',
          )).isSuccess,
          isFalse,
        );
      }
    },
  );

  test(
    'load after close and late completion do not emit or chain extra reads',
    () async {
      final repository = _ControlledRepository();
      final cubit = InteractionStatsCubit(repository);
      final pending = cubit.load(targetType: 'MEDIA', targetId: 'a');
      await cubit.close();
      repository.counts.single.complete(const Result.success(3));
      await expectLater(pending, completes);
      await cubit.load(targetType: 'MEDIA', targetId: 'a');
      await cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      expect(repository.counts, hasLength(1));
      expect(repository.commentReads, 0);
      expect(repository.writes, isEmpty);
    },
  );

  test(
    'duplicate toggle and concurrent refresh cannot dispatch opposite writes',
    () async {
      final repository = _ControlledRepository();
      final cubit = InteractionStatsCubit(repository);
      addTearDown(cubit.close);
      await _load(cubit, repository);
      final write = cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      await cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      await cubit.load(targetType: 'MEDIA', targetId: 'a', force: true);
      expect(repository.writes, hasLength(1));
      expect(repository.desired, [true]);
      expect(repository.counts, hasLength(1));
      repository.liked = true;
      repository.writes.single.complete(const Result.success(null));
      await Future<void>.delayed(Duration.zero);
      repository.counts.last.complete(const Result.success(5));
      await write;
      expect(cubit.state.items['MEDIA:a']?.loading, isFalse);
      expect(cubit.state.items['MEDIA:a']?.isLiked, isTrue);
      expect(() => cubit.state.items.clear(), throwsUnsupportedError);
    },
  );

  test(
    'initial load prevents a speculative toggle until liked state is known',
    () async {
      final repository = _ControlledRepository();
      final cubit = InteractionStatsCubit(repository);
      addTearDown(cubit.close);
      final read = cubit.load(targetType: 'MEDIA', targetId: 'a');
      await cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      expect(repository.writes, isEmpty);
      repository.counts.single.complete(const Result.success(3));
      await read;
    },
  );

  test(
    'thrown load releases busy state and an explicit load retries',
    () async {
      final repository = _ControlledRepository();
      final cubit = InteractionStatsCubit(repository);
      addTearDown(cubit.close);
      final read = cubit.load(targetType: 'MEDIA', targetId: 'a');
      repository.counts.single.completeError(StateError('offline'));
      await read;
      expect(cubit.state.items['MEDIA:a']?.loading, isFalse);
      expect(cubit.state.items['MEDIA:a']?.error, isNotNull);
      await _load(cubit, repository);
      expect(cubit.state.items['MEDIA:a']?.error, isNull);
    },
  );

  test(
    'uncertain write requires server reconciliation before another mutation',
    () async {
      final repository = _ControlledRepository();
      final cubit = InteractionStatsCubit(repository);
      addTearDown(cubit.close);
      await _load(cubit, repository);
      final write = cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      repository.writes.single.completeError(
        StateError('response lost after commit'),
      );
      await write;
      expect(cubit.state.items['MEDIA:a']?.loading, isFalse);
      repository.liked =
          true; // The write committed even though its response was lost.
      final reconcile = cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      expect(repository.writes, hasLength(1));
      repository.counts.last.complete(const Result.success(5));
      await reconcile;
      expect(cubit.state.items['MEDIA:a']?.isLiked, isTrue);
      final unlike = cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      expect(repository.desired, [true, false]);
      repository.writes.last.complete(const Result.failure(_error));
      await unlike;
    },
  );

  test(
    'failed personal-state read blocks toggle and remains retryable',
    () async {
      final repository = _ControlledRepository()..likedError = _error;
      final cubit = InteractionStatsCubit(repository);
      addTearDown(cubit.close);
      await _load(cubit, repository);
      expect(cubit.state.items['MEDIA:a']?.error, same(_error));
      final reconcile = cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      expect(repository.writes, isEmpty);
      repository.likedError = null;
      repository.counts.last.complete(const Result.success(4));
      await reconcile;
      expect(cubit.state.items['MEDIA:a']?.error, isNull);
    },
  );

  test(
    'session switch clears cache and old write cannot overwrite new account load',
    () async {
      final sessions = AudienceTestSessions(audienceSession());
      final repository = _ControlledRepository();
      final cubit = InteractionStatsCubit(repository, sessions: sessions);
      addTearDown(() async {
        await cubit.close();
        sessions.dispose();
      });
      await _load(cubit, repository);
      final write = cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      sessions.replace(audienceSession(user: 'other', token: 'other'));
      expect(cubit.state.items['MEDIA:a']?.isLiked, isFalse);
      repository.counts.last.complete(const Result.success(7));
      await Future<void>.delayed(Duration.zero);
      repository.writes.single.complete(const Result.success(null));
      await write;
      expect(repository.counts, hasLength(2));
      expect(cubit.state.items['MEDIA:a']?.likeCount, 7);
      expect(cubit.state.items['MEDIA:a']?.isLiked, isFalse);
      sessions.replace(const AuthSession.guest());
      expect(cubit.state.items, isEmpty);
      await cubit.toggleLike(targetType: 'MEDIA', targetId: 'a');
      expect(repository.writes, hasLength(1));
    },
  );
}

Object? _payload(_Operation operation) => switch (operation) {
  _Operation.count => 4,
  _Operation.state => false,
  _ => null,
};

Future<Result<dynamic>> _request(
  EngagementRepositoryImpl repository,
  _Operation operation, [
  String id = 'asset',
]) => switch (operation) {
  _Operation.like => repository.like(targetType: 'MEDIA', targetId: id),
  _Operation.unlike => repository.unlike(targetType: 'MEDIA', targetId: id),
  _Operation.count => repository.getLikeCount(
    targetType: 'MEDIA',
    targetId: id,
  ),
  _Operation.state => repository.isLiked(targetType: 'MEDIA', targetId: id),
};

Future<void> _load(
  InteractionStatsCubit cubit,
  _ControlledRepository repository,
) async {
  final pending = cubit.load(targetType: 'MEDIA', targetId: 'a');
  repository.counts.last.complete(const Result.success(4));
  await pending;
}

class _ControlledRepository extends Fake implements EngagementRepository {
  final counts = <Completer<Result<int>>>[];
  final writes = <Completer<Result<void>>>[];
  final desired = <bool>[];
  int commentReads = 0;
  bool liked = false;
  AppError? likedError;

  @override
  Future<Result<int>> getLikeCount({
    required String targetType,
    required String targetId,
  }) {
    final pending = Completer<Result<int>>();
    counts.add(pending);
    return pending.future;
  }

  @override
  Future<Result<CommentPage>> listComments({
    required String targetType,
    required String targetId,
    int page = 0,
    int size = 20,
  }) async {
    commentReads++;
    return const Result.success(CommentPage(items: [], totalElements: 2));
  }

  @override
  Future<Result<bool>> isLiked({
    required String targetType,
    required String targetId,
  }) async =>
      likedError == null ? Result.success(liked) : Result.failure(likedError!);
  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) => _write(true);
  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) => _write(false);
  Future<Result<void>> _write(bool value) {
    desired.add(value);
    final pending = Completer<Result<void>>();
    writes.add(pending);
    return pending.future;
  }
}
