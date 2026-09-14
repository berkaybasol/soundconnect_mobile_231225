import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:soundconnect_23_12_25codx/core/error/app_error.dart';
import 'package:soundconnect_23_12_25codx/core/error/result.dart';
import 'package:soundconnect_23_12_25codx/modules/collab/domain/collab_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/engagement/domain/engagement_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/band_follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/follow/domain/follow_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_models.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/domain/musician_feed_repository.dart';
import 'package:soundconnect_23_12_25codx/modules/musician_feed/presentation/cubit/musician_feed_cubit.dart';

import 'support/event_audience_fakes.dart';

void main() {
  for (final action in ['like', 'save']) {
    for (final refreshFirst in [true, false]) {
      for (final writeFinishesFirst in [true, false]) {
        for (final succeeds in [true, false]) {
          test(
            '$action refresh-first=$refreshFirst write-finishes-first='
            '$writeFinishesFirst success=$succeeds reconciles refreshed aliases',
            () async {
              final rig = _Rig(action);
              await rig.initialize();
              final read = rig.nextRead();
              final write = rig.nextWrite();
              late Future<void> refreshing;
              late Future<bool> changing;
              if (refreshFirst) {
                refreshing = rig.cubit.refresh();
                changing = rig.toggle(true);
              } else {
                changing = rig.toggle(true);
                refreshing = rig.cubit.refresh();
              }
              bool? outcome;
              if (writeFinishesFirst) {
                write.complete(_result(succeeds));
                outcome = await changing;
              }
              read.complete(
                Result.success(
                  _page([
                    _item(action, count: 9, title: 'fresh'),
                    _item(action, id: 'alias', count: 9, title: 'fresh alias'),
                  ]),
                ),
              );
              await refreshing;
              if (!writeFinishesFirst) {
                expect(rig.cubit.state.pendingItemIds, {'card', 'alias'});
                write.complete(_result(succeeds));
                outcome = await changing;
              }
              expect(outcome, succeeds);
              expect(rig.cubit.state.pendingItemIds, isEmpty);
              expect(
                rig.cubit.state.items.map(rig.selected),
                everyElement(succeeds),
              );
              expect(rig.cubit.state.items.map(_title), [
                'fresh',
                'fresh alias',
              ]);
              if (action == 'like') {
                expect(
                  rig.cubit.state.items.map(
                    (item) => item.engagement!.likeCount,
                  ),
                  everyElement(succeeds ? 10 : 9),
                );
              }
            },
          );
        }
      }
    }

    test(
      '$action pending write survives multiple overlapping refreshes',
      () async {
        final rig = _Rig(action);
        await rig.initialize();
        final write = rig.nextWrite();
        final changing = rig.toggle(true);
        final older = rig.nextRead();
        final oldRefresh = rig.cubit.refresh();
        final newer = rig.nextRead();
        final newRefresh = rig.cubit.refresh();
        older.complete(Result.success(_page([_item(action, count: 99)])));
        await oldRefresh;
        newer.complete(Result.success(_page([_item(action, count: 9)])));
        await newRefresh;
        write.complete(_result(true));
        expect(await changing, isTrue);
        expect(rig.selected(rig.cubit.state.items.single), isTrue);
        if (action == 'like') {
          expect(rig.cubit.state.items.single.engagement!.likeCount, 10);
        }
        expect(rig.cubit.state.pendingItemIds, isEmpty);
      },
    );

    test(
      '$action a read started after completion honors later server changes',
      () async {
        final rig = _Rig(action);
        await rig.initialize();
        final older = rig.nextRead();
        final oldRefresh = rig.cubit.refresh();
        final write = rig.nextWrite();
        final changing = rig.toggle(true);
        write.complete(_result(true));
        expect(await changing, isTrue);
        final newer = rig.nextRead();
        final newRefresh = rig.cubit.refresh();
        // Another screen/device has undone the write before this newer read.
        newer.complete(Result.success(_page([_item(action, count: 21)])));
        await newRefresh;
        older.complete(Result.success(_page([_item(action, selected: true)])));
        await oldRefresh;
        expect(rig.selected(rig.cubit.state.items.single), isFalse);
        if (action == 'like') {
          expect(rig.cubit.state.items.single.engagement!.likeCount, 21);
        }
      },
    );

    for (final secondSucceeds in [true, false]) {
      test('$action retains consecutive writes while one refresh is in flight '
          '(second success=$secondSucceeds)', () async {
        final rig = _Rig(action);
        await rig.initialize();
        final read = rig.nextRead();
        final refreshing = rig.cubit.refresh();
        final first = rig.nextWrite();
        final firstChange = rig.toggle(true);
        first.complete(_result(true));
        expect(await firstChange, isTrue);
        final second = rig.nextWrite();
        final secondChange = rig.toggle(false);
        second.complete(_result(secondSucceeds));
        expect(await secondChange, secondSucceeds);
        read.complete(Result.success(_page([_item(action, count: 9)])));
        await refreshing;
        expect(rig.selected(rig.cubit.state.items.single), !secondSucceeds);
        if (action == 'like') {
          expect(
            rig.cubit.state.items.single.engagement!.likeCount,
            secondSucceeds ? 9 : 10,
          );
        }
      });
    }

    test(
      '$action cannot project an old-account write into a refreshed account',
      () async {
        final rig = _Rig(action);
        await rig.initialize();
        final oldWrite = rig.nextWrite();
        final changing = rig.toggle(true);
        final oldRead = rig.nextRead();
        final oldRefresh = rig.cubit.refresh();
        rig.sessions.replace(
          audienceSession(
            user: 'replacement',
            token: 'replacement-token',
            role: 'ROLE_MUSICIAN',
          ),
        );
        final newRead = rig.nextRead();
        final newRefresh = rig.cubit.refresh();
        newRead.complete(
          Result.success(
            _page([_item(action, count: 18, title: 'new account')]),
          ),
        );
        await newRefresh;
        oldRead.complete(
          Result.success(_page([_item(action, selected: true)])),
        );
        await oldRefresh;
        oldWrite.complete(_result(true));
        expect(await changing, isFalse);
        expect(rig.selected(rig.cubit.state.items.single), isFalse);
        expect(_title(rig.cubit.state.items.single), 'new account');
        expect(rig.cubit.state.pendingItemIds, isEmpty);
      },
    );
  }

  test(
    'refresh containing a committed like does not increment its fresh count twice',
    () async {
      final rig = _Rig('like');
      await rig.initialize();
      final write = rig.nextWrite();
      final changing = rig.toggle(true);
      final read = rig.nextRead();
      final refreshing = rig.cubit.refresh();
      read.complete(
        Result.success(_page([_item('like', selected: true, count: 18)])),
      );
      await refreshing;
      write.complete(_result(true));
      expect(await changing, isTrue);
      expect(rig.cubit.state.items.single.engagement!.likeCount, 18);
    },
  );
}

Result<void> _result(bool succeeds) => succeeds
    ? const Result.success(null)
    : const Result.failure(AppError(code: 'write-failed', message: 'Failed'));

class _Rig {
  _Rig(this.action) {
    sessions = AudienceTestSessions(audienceSession(role: 'ROLE_MUSICIAN'));
    cubit = MusicianFeedCubit(
      feed,
      writes,
      collabRepository: writes,
      followRepository: _Follow(),
      bandFollowRepository: _BandFollow(),
      sessions: sessions,
    );
    addTearDown(sessions.dispose);
    addTearDown(cubit.close);
  }
  final String action;
  final feed = _Feed();
  final writes = _Writes();
  late final AudienceTestSessions sessions;
  late final MusicianFeedCubit cubit;
  Future<void> initialize() {
    feed.responses.add(Future.value(Result.success(_page([_item(action)]))));
    return cubit.initialize();
  }

  Completer<Result<MusicianFeedPage>> nextRead() {
    final read = Completer<Result<MusicianFeedPage>>();
    feed.responses.add(read.future);
    return read;
  }

  Completer<Result<void>> nextWrite() {
    final write = Completer<Result<void>>();
    writes.responses.add(write.future);
    return write;
  }

  Future<bool> toggle(bool selected) => action == 'like'
      ? cubit.toggleLike('card')
      : cubit.toggleCollabSaved('card', selected);
  bool selected(MusicianFeedItem item) => action == 'like'
      ? item.engagement!.likedByMe
      : (item.payload as CollabFeedPayload).listing['savedByMe'] == true;
}

String _title(MusicianFeedItem item) => switch (item.payload) {
  TrackFeedPayload payload => payload.title,
  CollabFeedPayload payload => payload.listing['title'] as String,
  _ => throw StateError('Unexpected test payload'),
};

MusicianFeedPage _page(List<MusicianFeedItem> items) => MusicianFeedPage(
  schemaVersion: 1,
  algorithmVersion: 'musician-v1',
  feedSessionId: 'session',
  generatedAt: DateTime.utc(2026, 9, 14),
  items: items,
  nextCursor: null,
  hasMore: false,
);

MusicianFeedItem _item(
  String action, {
  String id = 'card',
  int count = 2,
  bool selected = false,
  String title = 'initial',
}) => MusicianFeedItem(
  id: id,
  type: action == 'like'
      ? MusicianFeedItemType.track
      : MusicianFeedItemType.collab,
  payloadVersion: 1,
  occurredAt: DateTime.utc(2026, 9, 14),
  position: 0,
  impressionToken: 'delivery-$id',
  reason: const MusicianFeedReason(
    code: 'DISCOVERY',
    actors: [],
    secondaryActorCount: 0,
  ),
  author: null,
  target: const MusicianFeedTarget(type: 'MEDIA', id: 'media'),
  engagement: MusicianFeedEngagement(
    targetType: 'MEDIA',
    targetId: 'media',
    likeCount: count,
    commentCount: 1,
    likedByMe: selected,
    likable: true,
    commentable: true,
  ),
  promotion: null,
  feedbackCapabilities: const {},
  payload: action == 'like'
      ? TrackFeedPayload(
          trackId: 'track',
          mediaAssetId: 'media',
          title: title,
          playbackUrl: null,
          durationSeconds: 120,
          bpm: null,
        )
      : CollabFeedPayload(
          listing: {'id': 'listing', 'savedByMe': selected, 'title': title},
        ),
);

class _Feed extends Fake implements MusicianFeedRepository {
  final responses = Queue<Future<Result<MusicianFeedPage>>>();
  @override
  Future<Result<MusicianFeedPage>> load({required int limit, String? cursor}) =>
      responses.removeFirst();
  @override
  Future<Result<void>> recordEvent({
    required String clientEventId,
    required String impressionToken,
    required MusicianFeedTelemetryEventType eventType,
    DateTime? occurredAt,
  }) async => const Result.success(null);
}

class _Writes extends Fake implements EngagementRepository, CollabRepository {
  final responses = Queue<Future<Result<void>>>();
  @override
  Future<Result<void>> like({
    required String targetType,
    required String targetId,
  }) => responses.removeFirst();
  @override
  Future<Result<void>> unlike({
    required String targetType,
    required String targetId,
  }) => responses.removeFirst();
  @override
  Future<Result<void>> saveListing(String listingId) => responses.removeFirst();
  @override
  Future<Result<void>> unsaveListing(String listingId) =>
      responses.removeFirst();
}

class _Follow extends Fake implements FollowRepository {}

class _BandFollow extends Fake implements BandFollowRepository {}
